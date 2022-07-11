defmodule Altgwin.App do
  use Application

  @impl true
  def start(_, _) do
    children = [
      {PackageRepository, "packages.db"},
      {Finch, name: FinchClient},
      {Plug.Cowboy, scheme: :http, plug: Server, options: [port: 80]},
      {Task.Supervisor, name: TaskSupervisor}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
