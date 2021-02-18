#include "RtMidi.h"
#include <erl_nif.h>
#include <unordered_map>
#include <iostream>
#include <string>

// *** README ***
// Many of these methods have overlap with methods of the same name in `ex_rtmidi_input.cpp`
// As such, I'll frequently reference reading the comments in that file to reduce duplication
// (also, this is why I believe this should be refactored into a more OO approach)
// *** END README ***

// see `ex_rtmidi_input.cpp`
#define MAXBUFLEN 1024

// see `ex_rtmidi_input.cpp`
typedef std::function<ERL_NIF_TERM(RtMidiOut*)> erl_midi_cb_t;
typedef std::function<ERL_NIF_TERM(RtMidiOut*, int)> erl_port_cb_t;

typedef struct {
  ERL_NIF_TERM atom_ok;
  ERL_NIF_TERM atom_error;
  ERL_NIF_TERM atom_port_out_of_range;
  ERL_NIF_TERM atom_instance_name_taken;
  ERL_NIF_TERM atom_instance_not_found;
} ex_rtmidi_priv;

ex_rtmidi_priv* priv;
// The container for the midi instances
std::unordered_map<std::string, RtMidiOut*> midi_out_instances;

// see `ex_rtmidi_input.cpp`
static bool instance_exists(char name[]) {
  return midi_out_instances.find(std::string(name)) != midi_out_instances.end();
}

// see `ex_rtmidi_input.cpp`
static RtMidiOut* get_instance_by_name(char name[]) {
  return midi_out_instances[std::string(name)];
}

// see `ex_rtmidi_input.cpp`
static ERL_NIF_TERM get_name_from_nif(ErlNifEnv* env, const ERL_NIF_TERM name_argv, char* buf) {
  uint32_t name_length;
  enif_get_list_length(env, name_argv, &name_length);

  return enif_get_string(env, name_argv, buf, name_length + 1, ERL_NIF_LATIN1);
} 

// see `ex_rtmidi_input.cpp`
static ERL_NIF_TERM wrap_instance_exists(ErlNifEnv* env, const ERL_NIF_TERM name_argv, const erl_midi_cb_t &cb) {
  priv = (ex_rtmidi_priv*)enif_priv_data(env);
  char instance_name[MAXBUFLEN];

  if (!get_name_from_nif(env, name_argv, instance_name)) {
  	return enif_make_badarg(env);
  }

  if (!instance_exists(instance_name)) {
    return enif_make_tuple2(env, priv->atom_error, priv->atom_instance_not_found);
  } else {
    RtMidiOut *midi_instance = get_instance_by_name(instance_name);

    return cb(midi_instance);
  }
}

// see `ex_rtmidi_input.cpp`
static ERL_NIF_TERM wrap_instance_and_port_exists(
  ErlNifEnv* env, 
  const ERL_NIF_TERM name_argv, 
  const ERL_NIF_TERM port_argv, 
  const erl_port_cb_t &cb
) {
  uint32_t port_number;

  if (!enif_get_uint(env, port_argv, &port_number)) {
  	return enif_make_badarg(env);
  }

  return wrap_instance_exists(env, name_argv, [=](RtMidiOut *midi_instance) {
    if (port_number > (midi_instance->getPortCount() - 1)) {
      return enif_make_tuple2(env, priv->atom_error, priv->atom_port_out_of_range);
    } else {
      return cb(midi_instance, port_number);
    }
  });
}

// see `ex_rtmidi_input.cpp`
static ERL_NIF_TERM init(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  priv = (ex_rtmidi_priv*)enif_priv_data(env);
  char instance_name[MAXBUFLEN];

  if (!get_name_from_nif(env, argv[0], instance_name)) {
  	return enif_make_badarg(env);
  }

  if (instance_exists(instance_name)) {
    return enif_make_tuple2(env, priv->atom_error, priv->atom_instance_name_taken);
  } else {
    midi_out_instances[std::string(instance_name)] = new RtMidiOut();

    return priv->atom_ok;
  }
}

// see `ex_rtmidi_input.cpp`
static ERL_NIF_TERM get_port_count(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  return wrap_instance_exists(env, argv[0], [=](RtMidiOut *midi_instance) {
    return enif_make_tuple2(env, priv->atom_ok,  enif_make_int(env, midi_instance->getPortCount()));
  });
}

// see `ex_rtmidi_input.cpp`
static ERL_NIF_TERM get_port_name(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  return wrap_instance_and_port_exists(env, argv[0], argv[1], [=](RtMidiOut *midi_instance, int port_number) {
    const char* port_name = midi_instance->getPortName(port_number).c_str();

    return enif_make_tuple2(env, priv->atom_ok, enif_make_string(env, port_name, ERL_NIF_LATIN1));
  });
}

// see `ex_rtmidi_input.cpp`
static ERL_NIF_TERM open_port(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  return wrap_instance_and_port_exists(env, argv[0], argv[1], [=](RtMidiOut *midi_instance, int port_number) {
    midi_instance->openPort(port_number);

    return priv->atom_ok;
  });
}

// see `ex_rtmidi_input.cpp`
static ERL_NIF_TERM close_port(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  return wrap_instance_exists(env, argv[0], [=](RtMidiOut *midi_instance) {
    midi_instance->closePort();

    return priv->atom_ok;
  });
}

// Given an instance and a list of ints, converts that into a vector that RtMidi can work with
static ERL_NIF_TERM send_message(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  ERL_NIF_TERM list = argv[1];
  unsigned int length = 0;
  std::vector<unsigned char> msg_vec;
    
  if (!enif_get_list_length(env, list, &length)) {
    return enif_make_badarg(env);
  }

  // Copied from http://blog.techdominator.com/article/using-cpp-elixir-nifs.html
  int actual_head;
  ERL_NIF_TERM head;
  ERL_NIF_TERM tail;
  ERL_NIF_TERM current_list = list;

  // Iterate for each member in the list from Erlang
  for (unsigned int i = 0; i < length; ++i) {
    // Get upset if we can't get a given list cell saved to current_list
    if (!enif_get_list_cell(env, current_list, &head, &tail)) {
      return enif_make_badarg(env);
    }
    current_list = tail;
    // Get upset if we can't convert the current arg into an int
    if (!enif_get_int(env, head, &actual_head)) {
      return enif_make_badarg(env);
    }

    msg_vec.push_back((unsigned char)actual_head);
  }

  return wrap_instance_exists(env, argv[0], [=](RtMidiOut *midi_instance) {
    midi_instance->sendMessage(&msg_vec);

    return priv->atom_ok;
  });
}

static ErlNifFunc nif_funcs[] = {
  {"init", 1, init},
  {"get_port_count", 1, get_port_count},
  {"get_port_name", 2, get_port_name},
  {"open_port", 2, open_port},
  {"close_port", 1, close_port},
  {"send_message", 2, send_message}
};

static int load(ErlNifEnv* env, void** priv, ERL_NIF_TERM info) {
  ex_rtmidi_priv* data = (ex_rtmidi_priv*)enif_alloc(sizeof(ex_rtmidi_priv));

  if (data == NULL) {
    return 1;
  }

  data->atom_ok = enif_make_atom(env, "ok");
  data->atom_error = enif_make_atom(env, "error");
  data->atom_port_out_of_range = enif_make_atom(env, "port_out_of_range");
  data->atom_instance_name_taken = enif_make_atom(env, "instance_name_taken");
  data->atom_instance_not_found = enif_make_atom(env, "instance_not_found");

  *priv = (void*) data;

  return 0;
}

ERL_NIF_INIT(Elixir.ExRtmidi.Nifs.Output, nif_funcs, &load, NULL, NULL, NULL)
