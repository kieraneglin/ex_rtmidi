defmodule ExRtmidi.Message do
  @moduledoc """
  Contains methods to more completely cover creation of a MIDI message
  """

  alias ExRtmidi.Message.Spec
  alias ExRtmidi.Message.Encoder

  @doc """
  Returns a complete MIDI message based on the specified command and data (if present)
  """
  @spec compose(atom(), list()) :: list()
  def compose(command, data \\ []) do
    command
    |> Spec.construct(data)
    |> Encoder.encode()
  end
end
