defmodule ExRtmidi.Message.EncoderTest do
  use ExUnit.Case
  alias ExRtmidi.Message.Spec
  alias ExRtmidi.Message.Encoder

  describe "encode" do
    test "Encodes simple specs w/ channel data" do
      note_off_spec = Spec.construct(:note_off, channel: 0, note: 50, velocity: 60)
      note_on_spec = Spec.construct(:note_on, channel: 1, note: 51, velocity: 61)
      control_change_spec = Spec.construct(:control_change, channel: 2, control: 52, value: 62)

      assert Encoder.encode(note_off_spec) == [0x80, 50, 60]
      assert Encoder.encode(note_on_spec) == [0x91, 51, 61]
      assert Encoder.encode(control_change_spec) == [0xB2, 52, 62]
    end

    test "Encodes pitchwheel data for small numbers" do
      pitchwheel_spec = Spec.construct(:pitchwheel, channel: 0, pitch: 10)

      assert Encoder.encode(pitchwheel_spec) == [0xE0, 10, 0]
    end

    test "Encodes pitchwheel data for large numbers" do
      pitchwheel_spec = Spec.construct(:pitchwheel, channel: 0, pitch: 8191)

      assert Encoder.encode(pitchwheel_spec) == [0xE0, 127, 63]
    end

    test "Encodes pitchwheel data for small negative numbers" do
      pitchwheel_spec = Spec.construct(:pitchwheel, channel: 0, pitch: -10)

      assert Encoder.encode(pitchwheel_spec) == [0xE0, 118, -1]
    end

    test "Encodes pitchwheel data for large negative numbers" do
      pitchwheel_spec = Spec.construct(:pitchwheel, channel: 0, pitch: -8192)

      assert Encoder.encode(pitchwheel_spec) == [0xE0, 0, -64]
    end

    test "Encodes sysex data with proper terminators" do
      data = [1, 2, 3]
      sysex_spec = Spec.construct(:sysex, data: data)

      assert Encoder.encode(sysex_spec) == [0xF0] ++ data ++ [0xF7]
    end

    test "Encodes quarter_frame data as expected" do
      quarter_frame_spec = Spec.construct(:quarter_frame, frame_type: 1, frame_value: 2)

      assert Encoder.encode(quarter_frame_spec) == [0xF1, 18]
    end

    test "Encodes songpos data as expected" do
      # This is a repeat of pitchwheel so it won't be tested as throughly
      songpos = Spec.construct(:songpos, pos: 8000)

      assert Encoder.encode(songpos) == [0xF2, 64, 62]
    end

    test "Encodes simple specs as expected" do
      song_select_spec = Spec.construct(:song_select, song: 1)
      tune_request_spec = Spec.construct(:tune_request, nil)
      clock_spec = Spec.construct(:clock, nil)
      start_spec = Spec.construct(:start, nil)
      continue_spec = Spec.construct(:continue, nil)
      stop_spec = Spec.construct(:stop, nil)
      active_sensing_spec = Spec.construct(:active_sensing, nil)
      reset_spec = Spec.construct(:reset, nil)

      assert Encoder.encode(song_select_spec) == [0xF3, 1]
      assert Encoder.encode(tune_request_spec) == [0xF6]
      assert Encoder.encode(clock_spec) == [0xF8]
      assert Encoder.encode(start_spec) == [0xFA]
      assert Encoder.encode(continue_spec) == [0xFB]
      assert Encoder.encode(stop_spec) == [0xFC]
      assert Encoder.encode(active_sensing_spec) == [0xFE]
      assert Encoder.encode(reset_spec) == [0xFF]
    end
  end
end
