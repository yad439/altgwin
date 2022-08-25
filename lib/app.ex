defmodule Altgwin.App do
  use Application

  @impl true
  def start(_, _) do
    children = [
      {PackageRepository, database: "packages.db", name: PackageRepository},
      {Finch, name: FinchClient},
      {Plug.Cowboy, scheme: :http, plug: Server, options: [port: 8080]},
      {Task.Supervisor, name: TaskSupervisor}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
