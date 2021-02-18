defmodule ExRtmidi.Message.Encoder do
  @moduledoc """
  Contains methods for converting a spec into a well-formatted MIDI message

  Mostly meant to be used internally, but could be useful if you're extending this lib
  """

  use Bitwise
  alias ExRtmidi.Message.Spec

  # From the MIDI spec
  @simple_commands_with_channel_data [
    :note_off,
    :note_on,
    :control_change
  ]

  @doc """
  Returns a MIDI message for a given spec
  """
  @spec encode(%Spec{}) :: list()
  def encode(%Spec{
        command: command,
        status_byte: status_byte,
        data: [{:channel, channel} | control_data]
      })
      when command in @simple_commands_with_channel_data do
    [status_byte ||| channel] ++ Keyword.values(control_data)
  end

  def encode(%Spec{
        command: :pitchwheel,
        status_byte: status_byte,
        data: [channel: channel, pitch: pitch]
      }) do
    # Per MIDI spec, pitchwheel data is split into two seven-bit values
    [status_byte ||| channel] ++ [pitch &&& 0x7F, pitch >>> 7]
  end

  # https://en.wikipedia.org/wiki/Semantic_satiation
  def encode(%Spec{command: :sysex, status_byte: status_byte, data: [data: data]}) do
    # Per MIDI spec, sysex calls are terminated with 0xF7
    [status_byte] ++ data ++ [0xF7]
  end

  def encode(%Spec{
        command: :quarter_frame,
        status_byte: status_byte,
        data: [frame_type: type, frame_value: value]
      }) do
    [status_byte] ++ [type <<< 4 ||| value]
  end

  def encode(%Spec{command: :songpos, status_byte: status_byte, data: [pos: pos]}) do
    # Like pitchwheel, MIDI spec specifies splitting the value
    [status_byte] ++ [pos &&& 0x7F, pos >>> 7]
  end

  def encode(%Spec{command: _, status_byte: status_byte, data: data}) do
    [status_byte] ++ Keyword.values(data)
  end
end
