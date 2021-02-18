defmodule Mix.Tasks.Compile.Rtmidi do
  # TODO: I want this to be its own file in the proper location, but it isn't getting picked up on `mix test`.
  # Setting elixirc_paths didn't help, but I might be doing it wrong
  use Mix.Task

  @shortdoc "Compiles RtMidi"
  def run(_) do
    {result, _error_code} =
      System.cmd("make", ["priv/ex_rtmidi_output.so", "priv/ex_rtmidi_input.so"],
        stderr_to_stdout: true
      )

    Mix.shell().info(result)

    :ok
  end
end

defmodule ExRtmidi.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_rtmidi,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      compilers: [:rtmidi] ++ Mix.compilers(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    []
  end
end
