defmodule ExRtmidi.Message.Spec do
  @moduledoc """
  Contains methods that present a human-friendly function signature for creating MIDI messages.

  Note that this module doesn't create messages but is an intermediate step to help enforce message shape.
  """

  alias __MODULE__

  @enforce_keys [:command, :status_byte, :data]
  defstruct [:command, :status_byte, :data]

  # Per MIDI spec
  @status_bytes %{
    note_off: 0x80,
    note_on: 0x90,
    polytouch: 0xA0,
    control_change: 0xB0,
    program_change: 0xC0,
    aftertouch: 0xD0,
    pitchwheel: 0xE0,
    sysex: 0xF0,
    quarter_frame: 0xF1,
    songpos: 0xF2,
    song_select: 0xF3,
    tune_request: 0xF6,
    clock: 0xF8,
    start: 0xFA,
    continue: 0xFB,
    stop: 0xFC,
    active_sensing: 0xFE,
    reset: 0xFF
  }

  @commands_without_control_data [
    :tune_request,
    :clock,
    :start,
    :continue,
    :stop,
    :active_sensing,
    :reset
  ]

  @doc """
  Enforces arguments for a given command and returns a Spec struct for eventual encoding into a MIDI message.

  Notes:
  - No defaults are offered (eg: assuming channel 0 unless specified),
    so creating a wrapper to suit your needs is recommended
  - Trivial commands (such as :start) still have an arity of 2, even though they don't have any additional data.
    The Message module addresses this, but this is noteworthy if you're extending this lib directly
  """
  @spec construct(atom(), list()) :: %Spec{}
  def construct(command = :note_off, [channel: _, note: _, velocity: _] = data) do
    do_construct_spec(command, data)
  end

  def construct(command = :note_on, [channel: _, note: _, velocity: _] = data) do
    do_construct_spec(command, data)
  end

  def construct(command = :polytouch, [channel: _, note: _, value: _] = data) do
    do_construct_spec(command, data)
  end

  def construct(command = :control_change, [channel: _, control: _, value: _] = data) do
    do_construct_spec(command, data)
  end

  def construct(command = :program_change, [channel: _, program: _] = data) do
    do_construct_spec(command, data)
  end

  def construct(command = :aftertouch, [channel: _, value: _] = data) do
    do_construct_spec(command, data)
  end

  def construct(command = :pitchwheel, [channel: _, pitch: _] = data) do
    do_construct_spec(command, data)
  end

  def construct(command = :sysex, [data: _] = data) do
    do_construct_spec(command, data)
  end

  def construct(command = :quarter_frame, [frame_type: _, frame_value: _] = data) do
    do_construct_spec(command, data)
  end

  def construct(command = :songpos, [pos: _] = data) do
    do_construct_spec(command, data)
  end

  def construct(command = :song_select, [song: _] = data) do
    do_construct_spec(command, data)
  end

  def construct(command, _) when command in @commands_without_control_data do
    do_construct_spec(command, [])
  end

  defp do_construct_spec(command, data) do
    %Spec{command: command, status_byte: @status_bytes[command], data: data}
  end
end
