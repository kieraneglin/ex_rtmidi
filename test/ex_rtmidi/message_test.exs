defmodule ExRtmidi.MessageTest do
  use ExUnit.Case
  alias ExRtmidi.Message

  describe "compose" do
    test "Generates a valid message for commands with arguments" do
      msg = Message.compose(:note_off, channel: 1, note: 2, velocity: 3)

      assert [129, 2, 3] = msg
    end

    test "Generates a valid message for sysex commands" do
      msg = Message.compose(:sysex, data: [1, 2, 3, 4, 5])

      assert [240, 1, 2, 3, 4, 5, 247] = msg
    end

    test "Generates a valid message for simple commands" do
      assert [250] = Message.compose(:start)
    end
  end
end
