defmodule Altgwin.MixProject do
  use Mix.Project

  def project do
    [
      app: :altgwin,
      version: "1.0.0",
      elixir: ">= 1.12.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Altgwin.App, []},
      env: [mirror: "https://cygwin.mirror.constant.com/"]
    ]
  end

  defp deps do
    [
      {:finch, ">= 0.12.0"},
      {:floki, ">= 0.32.0"},
      {:temp, ">= 0.4.0"},
      {:exqlite, ">= 0.11.2"},
      {:plug_cowboy, ">= 2.0.0"},
      {:dialyxir, ">= 1.0.0", only: [:dev], runtime: false},
      {:mox, ">= 1.0.0", only: :test}
    ]
  end

  defp elixirc_paths(:test), do: ["test/support", "lib"]
  defp elixirc_paths(_), do: ["lib"]
end
