defmodule ExRtmidi.Output do
  @moduledoc """
  Contains methods that initialize and interface with output ports.

  Things of note:
  - init/1 should not be called frequently. Ideally, it should be called once at app boot (see comments)
  - Ensure you've opened a port before sending messages
  """

  alias ExRtmidi.Nifs.Output, as: OutputNif

  # TODO: while most other methods take 10-20 usec, this takes about 10 ms
  # The max recommended execution time for a NIF fn is 1ms, but this may be workable
  # due to the infrequency that it would likely be called.
  # Normal use case would be to call this one time but send messages frequently
  @doc """
  Creates an RtMidi output instance under the specified name.

  The name you pass will be used to reference this instance going forward.
  """
  @spec init(atom()) :: {:error, any()} | {:ok, atom()}
  def init(instance_name) when is_atom(instance_name) do
    result =
      instance_name
      |> Atom.to_charlist()
      |> OutputNif.init()

    case result do
      :ok -> {:ok, instance_name}
      {:error, msg} -> {:error, msg}
    end
  end

  @doc """
  Returns the count of available output ports for a given RtMidi instance
  """
  @spec get_port_count(atom()) :: {:error, any()} | {:ok, integer()}
  def get_port_count(instance_name) when is_atom(instance_name) do
    instance_name
    |> Atom.to_charlist()
    |> OutputNif.get_port_count()
  end

  @doc """
  Returns the name of a port for a given instance and port index
  """
  @spec get_port_name(atom(), integer()) :: {:error, any()} | {:ok, String.t()}
  def get_port_name(instance_name, port_idx)
      when is_atom(instance_name) and is_integer(port_idx) do
    formatted_instance_name = Atom.to_charlist(instance_name)

    case OutputNif.get_port_name(formatted_instance_name, port_idx) do
      {:error, msg} -> {:error, msg}
      {:ok, instance_name} -> {:ok, List.to_string(instance_name)}
    end
  end

  @doc """
  Does the same as get_port_name/2 but gets a lot more upset if the specified index doesn't exist
  """
  @spec get_port_name!(atom(), integer()) :: String.t()
  def get_port_name!(instance_name, port_idx)
      when is_atom(instance_name) and is_integer(port_idx) do
    {:ok, port_name} = get_port_name(instance_name, port_idx)

    port_name
  end

  @doc """
  Returns a list of port names for a given instance
  """
  @spec get_ports(atom()) :: {:error, any()} | {:ok, list()}
  def get_ports(instance_name) when is_atom(instance_name) do
    case get_port_count(instance_name) do
      {:ok, port_count} ->
        # bang method should be safe here because we've ensured that `n` ports exist
        port_names =
          Enum.map(0..(port_count - 1), fn idx -> get_port_name!(instance_name, idx) end)

        {:ok, port_names}

      {:error, msg} ->
        {:error, msg}
    end
  end

  @doc """
  Opens a given port by index or name on the given instance

  Maximum of one open port per instance
  """
  @spec open_port(atom(), integer()) :: {:error, any()} | :ok
  def open_port(instance_name, port_idx) when is_atom(instance_name) and is_integer(port_idx) do
    instance_name
    |> Atom.to_charlist()
    |> OutputNif.open_port(port_idx)
  end

  def open_port(instance_name, port_name) when is_atom(instance_name) and is_binary(port_name) do
    case get_ports(instance_name) do
      {:ok, port_names} ->
        port_index = Enum.find_index(port_names, fn port -> port == port_name end)

        case port_index do
          nil -> {:error, :port_not_found}
          _ -> open_port(instance_name, port_index)
        end

      {:error, msg} ->
        {:error, msg}
    end
  end

  @doc """
  Closes the open port on the given instance, if it exists. Safe to call even if no port is open
  """
  @spec close_port(atom()) :: {:error, any()} | :ok
  def close_port(instance_name) when is_atom(instance_name) do
    instance_name
    |> Atom.to_charlist()
    |> OutputNif.close_port()
  end

  @doc """
  Sends a given MIDI message to the instance's open port
  """
  @spec send_message(atom(), list()) :: {:error, any()} | :ok
  def send_message(instance_name, message) when is_atom(instance_name) and is_list(message) do
    instance_name
    |> Atom.to_charlist()
    |> OutputNif.send_message(message)
  end
end
