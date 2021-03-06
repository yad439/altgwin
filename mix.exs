defmodule Altgwin.MixProject do
  use Mix.Project

  def project do
    [
      app: :altgwin,
      version: "1.0.0",
      elixir: ">= 1.12.0",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:plug_cowboy, ">= 2.0.0"}
    ]
  end
end
