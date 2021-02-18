defmodule ExRtmidi.Nifs.Input do
  @moduledoc false

  @on_load :load_nif

  def load_nif do
    path = Application.app_dir(:ex_rtmidi, "priv/ex_rtmidi_input") |> String.to_charlist()
    :ok = :erlang.load_nif(path, 0)
  end

  def init(_instance_name) do
    :erlang.nif_error("NIF not loaded")
  end

  def get_port_count(_instance_name) do
    :erlang.nif_error("NIF not loaded")
  end

  def get_port_name(_instance_name, _port_idx) do
    :erlang.nif_error("NIF not loaded")
  end

  def open_port(_instance_name, _port_idx) do
    :erlang.nif_error("NIF not loaded")
  end

  def close_port(_instance_name) do
    :erlang.nif_error("NIF not loaded")
  end

  def attach_listener(_instance_name, _pid) do
    :erlang.nif_error("NIF not loaded")
  end

  def detach_listener(_instance_name) do
    :erlang.nif_error("NIF not loaded")
  end
end
