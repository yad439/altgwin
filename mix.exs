defmodule Altgwin.MixProject do
  use Mix.Project

  def project do
    [
      app: :altgwin,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      escript: [main_module: Altgwin],
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
      # mod: {Altgwin, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:finch, ">= 0.12.0"},
      {:floki, ">= 0.32.0"},
      # {:ex_zstd, ">= 0.1.0"},
      # {:xz, ">= 0.3.0"}
      {:temp, ">= 0.4.0"},
      {:exqlite, ">= 0.11.2"}
    ]
  end
end
