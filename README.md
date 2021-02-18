# ExRtmidi

An Elixir wrapper for the [RtMidi][rtmidi] library. Inspired in part by [python-rtmidi][python-rtmidi].

Warning: This library is considered experimental/pre-alpha until some of the issues below are addressed.

## Help Needed

**Consider checking the "Issues" tab if you're looking to help.**

This library works as-is, but I'm not a C++ programmer. Any contributions are welcome, but help in these specific areas would go a long way:

- C++
  - **Major**
    - `src/ex_rtmidi_{output,input}.cpp` could much better utilize OOP and templating to reduce code duplication
    - General refactor to better follow C++ conventions
    - Auditing the code for safety (ie: avoiding crashing BEAM). Ideally after the above refactor
      - `input_callback` and `attach_listener` in `src/ex_rtmidi_input.cpp` need a good look. Again, a refactor beforehand is preferrable
    - Auditing the Makefile/adding support for Linux and Windows as a build target
  - **Minor**
    - `detach_listener` should not print an error if called without a listener

- Elixir
  - **Major**
    - The `init` method for inputs/outputs takes longer than recommended for a NIF. See `lib/ex_rtmidi/{output,input}.ex` comments
  - **Minor**
    - There is no support for RtMidi's `openVirtualPort`
    - More convenience methods for parsing incoming messages could be added
    - Move `Mix.Tasks.Compile.Rtmidi` out of `mix.exs`.  See comment in `mix.exs`

- General
  - **Major**
    - There are no C++ tests or tests for the NIF directly. Ideally a Dockerfile would be added in which tests can be run
    - GitHub CI should be added once the above is solved
  - **Minor**
    - Adding a Dockerfile to aid in local development and testing
    - Add a directory of examples for common use cases

## Architecture

C++ is an OO language, Elixir is not. I was torn on whether to express things more functionally or more in line with OO conventions. In the end a more functional approach was chosen.

To create an RtMidi instance, an `init` method is called with an instance identifier.  In C++ the instance is stored as a value in a map where the identifier is the key.  Future calls to RtMidi instance methods require the identifier be passed in order to know what instance to target.

NIFs are primarily an Erlang construct, so you'll see that the Elixir wrapper does a lot of converstion to and from charlists. This is because strings in Erlang are charlists in Elixir, therefore NIF string methods actually take and return charlists instead of `String.t()`.

Listeners on input ports as passed to C++ as a PID. Upon receipt of a message, the NIF parses and passes the message up async to the specified PID.

## Why?

1. I prefer Elixir over Python
2. Pattern matching MIDI messages is a really good fit
3. Elixir's process mechanisms (especially GenServers) are ideal for consuming MIDI input

## Installation

Until some of the more pressing C++ issues get resolved I don't want to promote this library for public use.  Until then, you'll have to get it from GitHub:

```elixir
def deps do
  [
    {:ex_rtmidi, git: "https://github.com/kieraneglin/ex_rtmidi"}
  ]
end
```

## Usage

Currently, this library take a more bare-bones approach to handling messages than you may expect.  You may get value from a small wrapper around sending and parsing messages tailored to your use case.

I've outlined some basic use cases, but you should see `lib/ex_rtmidi/{output,input}.ex` for more in-depth documentation.

### Output

```elixir
alias ExRtmidi.Output

{:ok, instance} = Output.init(:my_instance_name) # Instance name can be whatever you want - it's unrelated to available MIDI devices

Output.get_port_count(instance) 
# iex> {:ok, 2}

Output.get_ports(instance)
# iex> {:ok, ["IAC Midi", "Dummy MIDI"]}

Output.open_port(instance, 0) # Or `Output.open_port(instance, "IAC Midi")`
# iex> :ok

Output.send_message(instance, [0x90, 60, 100])
# iex> :ok

Output.close_port(instance)
# iex> :ok
```

### Messages

There is a wrapper for MIDI messages that improves the experience of creating messages.  This is mainly for output and hasn't been ported to deconstruct incoming messages (see the "Help Needed" section).

For a full list of messages, see `lib/ex_rtmidi/message/spec.ex`.

```elixir
alias ExRtmidi.Output
alias ExRtmidi.Message

# Assume `init` has been run and a port has been opened as in the instance above

message = Message.compose(:note_on, channel: 0, note: 60, velocity: 100)

Output.send_message(instance, message)
```

### Input

```elixir
# In midi_input_server.ex
defmodule MidiInputServer do
  use GenServer

  def init(state \\ []) do
    {:ok, state}
  end

  def handle_info({:midi_input, midi_message}, state) do
    IO.inspect(midi_message)

    {:noreply, state}
  end
end

# In another file

alias ExRtmidi.Input

# Much of setup including init, listing ports, and opening a port is the same as in the Output example above.
# Setup will be omitted for brevity.  Assume we have an instance at our disposal.

{:ok, midi_listener_pid} = GenServer.start_link(MidiInputServer, [])

# You should attach the listener before opening the port to ensure no messages get missed
Input.attach_listener(instance, midi_listener_pid)
# iex> :ok

Input.open_port(instance)
# iex> :ok

# Messages will be handled from this point on
# When you're done, be sure to detatch the listener before closing the port
Input.detatch_listener(instance)
# iex> :ok

Input.close_port(instance)
# iex> :ok
```

## License (MIT)

Copyright 2021

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


[rtmidi]: https://www.music.mcgill.ca/~gary/rtmidi/
[python-rtmidi]: https://github.com/SpotlightKid/python-rtmidi
