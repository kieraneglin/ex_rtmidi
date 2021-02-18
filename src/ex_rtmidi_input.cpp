#include "RtMidi.h"
#include <erl_nif.h>
#include <unordered_map>
#include <iostream>
#include <string>
#include<tuple>

// TODO: is this needed? Seems to be a very C thing, but the NIF doesn't play well with C++ strings
#define MAXBUFLEN 1024

// Types expressing the two existence wrapper callbacks
typedef std::function<ERL_NIF_TERM(RtMidiIn*)> erl_midi_cb_t;
typedef std::function<ERL_NIF_TERM(RtMidiIn*, int)> erl_port_cb_t;

typedef struct {
  ERL_NIF_TERM atom_ok;
  ERL_NIF_TERM atom_error;
  ERL_NIF_TERM atom_midi_input;
  ERL_NIF_TERM atom_port_out_of_range;
  ERL_NIF_TERM atom_instance_name_taken;
  ERL_NIF_TERM atom_instance_not_found;
} ex_rtmidi_priv;

ex_rtmidi_priv* priv;
// The container for the midi instances
std::unordered_map<std::string, RtMidiIn*> midi_in_instances;

// Returns a boolean representing whether the provided name exists in our instance container
static bool instance_exists(char name[]) {
  // Don't ask me why, but this is how you check member existence in c++ < 20, apparently
  return midi_in_instances.find(std::string(name)) != midi_in_instances.end();
}

// Returns an RtMidi instance associated with a given name
static RtMidiIn* get_instance_by_name(char name[]) {
  return midi_in_instances[std::string(name)];
}

// Takes a NIF_TERM argument that should represent the instance's name 
// and attempts to convert it into a string for easier use within C++ land
static ERL_NIF_TERM get_name_from_nif(ErlNifEnv* env, const ERL_NIF_TERM name_argv, char* buf) {
  // NOTE: Is this the best way to get the length of a charlist from Erlang?
  uint32_t name_length;
  enif_get_list_length(env, name_argv, &name_length);

  return enif_get_string(env, name_argv, buf, name_length + 1, ERL_NIF_LATIN1);
} 

// Checks if an instance associated with a given name exists.  If so, passes that instance into the provided callback
// This allows a lot of boilerplate to be skipped around error handling and NIF_TERM conversion
static ERL_NIF_TERM wrap_instance_exists(ErlNifEnv* env, const ERL_NIF_TERM name_argv, const erl_midi_cb_t &cb) {
  priv = (ex_rtmidi_priv*)enif_priv_data(env);
  char instance_name[MAXBUFLEN];

  if (!get_name_from_nif(env, name_argv, instance_name)) {
  	return enif_make_badarg(env);
  }

  if (!instance_exists(instance_name)) {
    return enif_make_tuple2(env, priv->atom_error, priv->atom_instance_not_found);
  } else {
    RtMidiIn *midi_instance = get_instance_by_name(instance_name);

    return cb(midi_instance);
  }
}

// Same as above, but additionally checks that the port index we're trying to interface with exists
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

  return wrap_instance_exists(env, name_argv, [=](RtMidiIn *midi_instance) {
    if (port_number > (midi_instance->getPortCount() - 1)) {
      return enif_make_tuple2(env, priv->atom_error, priv->atom_port_out_of_range);
    } else {
      return cb(midi_instance, port_number);
    }
  });
}

// Creates a new instance and stores it with the given name.  If the name is already taken, an error is returned
static ERL_NIF_TERM init(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  priv = (ex_rtmidi_priv*)enif_priv_data(env);
  char instance_name[MAXBUFLEN];

  if (!get_name_from_nif(env, argv[0], instance_name)) {
  	return enif_make_badarg(env);
  }

  if (instance_exists(instance_name)) {
    return enif_make_tuple2(env, priv->atom_error, priv->atom_instance_name_taken);
  } else {
    midi_in_instances[std::string(instance_name)] = new RtMidiIn();

    return priv->atom_ok;
  }
}

// Self-explanatory
static ERL_NIF_TERM get_port_count(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  return wrap_instance_exists(env, argv[0], [=](RtMidiIn *midi_instance) {
    return enif_make_tuple2(env, priv->atom_ok,  enif_make_int(env, midi_instance->getPortCount()));
  });
}

// Given an instance name and a port index, returns the string name of that port
static ERL_NIF_TERM get_port_name(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  return wrap_instance_and_port_exists(env, argv[0], argv[1], [=](RtMidiIn *midi_instance, int port_number) {
    const char* port_name = midi_instance->getPortName(port_number).c_str();

    return enif_make_tuple2(env, priv->atom_ok, enif_make_string(env, port_name, ERL_NIF_LATIN1));
  });
}

// Opens the specified port on the given instance.  Only one port can be open per instance
static ERL_NIF_TERM open_port(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  return wrap_instance_and_port_exists(env, argv[0], argv[1], [=](RtMidiIn *midi_instance, int port_number) {
    midi_instance->openPort(port_number);

    return priv->atom_ok;
  });
}

// Closes the open port on an instance.  Is safe to call even if no port is open
static ERL_NIF_TERM close_port(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  return wrap_instance_exists(env, argv[0], [=](RtMidiIn *midi_instance) {
    midi_instance->closePort();

    return priv->atom_ok;
  });
}

// TODO: this needs more experienced eyes looking at it
// Conforms to the shape needed by RtMidi's setCallback method
// In practice, converts a MIDI message into a list of NIF_TERMs and sends that list to the callback PID
static void input_callback(double timestamp, std::vector<unsigned char> *message, void *context_data) {
  // TODO: Is this needed?
  ErlNifEnv* env = enif_alloc_env();
  ErlNifPid* pid = reinterpret_cast<ErlNifPid*>(context_data);
  ERL_NIF_TERM list = enif_make_list(env, 0);

  for (int i = message->size() - 1; i >= 0; i--) {
    list = enif_make_list_cell(env, enif_make_int(env, (int)message->at(i)), list);
  }

  // TODO: the specific incantations of what ENVs to pass in what order (vs. NULL) is completely unclear to me
  // This works, but I don't know _why_ at a deep level
  enif_send(NULL, pid, env, enif_make_tuple2(env, priv->atom_midi_input, list));
  // TODO: is this needed?
  enif_free_env(env);
}

// TODO: this needs more experienced eyes looking at it
// Takes an instance name and the PID of a listener process and configures RtMidi to send callback data to that PID
static ERL_NIF_TERM attach_listener(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  return wrap_instance_exists(env, argv[0], [=](RtMidiIn *midi_instance) {
    ErlNifPid erl_pid;

    if (!enif_get_local_pid(env, argv[1], &erl_pid)) {
      return enif_make_badarg(env);
    }

    midi_instance->setCallback(&input_callback, &erl_pid);

    return priv->atom_ok;
  });
}

// TODO: should track listener existence so this doesn't print an error if no listener exists (same as close_port)
// Cancels the attached RtMidi callback
static ERL_NIF_TERM detach_listener(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  return wrap_instance_exists(env, argv[0], [=](RtMidiIn *midi_instance) {
    midi_instance->cancelCallback();

    return priv->atom_ok;
  });
}

static ErlNifFunc nif_funcs[] = {
  {"init", 1, init},
  {"get_port_count", 1, get_port_count},
  {"get_port_name", 2, get_port_name},
  {"open_port", 2, open_port},
  {"close_port", 1, close_port},
  {"attach_listener", 2, attach_listener},
  {"detach_listener", 1, detach_listener}
};

static int load(ErlNifEnv* env, void** priv, ERL_NIF_TERM info) {
  ex_rtmidi_priv* data = (ex_rtmidi_priv*)enif_alloc(sizeof(ex_rtmidi_priv));

  if (data == NULL) {
    return 1;
  }

  data->atom_ok = enif_make_atom(env, "ok");
  data->atom_error = enif_make_atom(env, "error");
  data->atom_midi_input = enif_make_atom(env, "midi_input");
  data->atom_port_out_of_range = enif_make_atom(env, "port_out_of_range");
  data->atom_instance_name_taken = enif_make_atom(env, "instance_name_taken");
  data->atom_instance_not_found = enif_make_atom(env, "instance_not_found");

  *priv = (void*) data;

  return 0;
}

ERL_NIF_INIT(Elixir.ExRtmidi.Nifs.Input, nif_funcs, &load, NULL, NULL, NULL)
