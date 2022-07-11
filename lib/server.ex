defmodule Server do
  use Plug.Router

  plug(Plug.Logger, log: :debug)
  plug(:auth)
  plug(Plug.Parsers, parsers: [:urlencoded])
  plug(:match)
  plug(:dispatch)

  defp auth(conn, _) do
    username = System.fetch_env!("AUTH_USERNAME")
    password = System.fetch_env!("AUTH_PASSWORD")
    Plug.BasicAuth.basic_auth(conn, username: username, password: password)
  end

  get "/download" do
    archive = Altgwin.prepare_download(conn.params["files"])
    conn = put_resp_content_type(conn, "application/zip")
    send_resp(conn, 200, archive)
  end

  get "/dependencies" do
    deps = PackageRepository.get_dependencies(PackageRepository, [conn.params["file"]])
    send_resp(conn, 200, Enum.join(deps, "\n"))
  end

  put "/dependencies" do
    :ok =
      PackageRepository.add_dependencies(
        PackageRepository,
        conn.params["file"],
        conn.params["dependencies"]
      )

    send_resp(conn, 201, <<>>)
  end

  delete "/dependencies" do
    :ok =
      PackageRepository.remove_dependency(
        PackageRepository,
        conn.params["file"],
        conn.params["dependency"]
      )

    send_resp(conn, 204, <<>>)
  end

  post "/update" do
    :ok = Altgwin.detect_outdated(Application.fetch_env!(:altgwin, :mirror))
    Task.Supervisor.start_child(TaskSupervisor, Altgwin, :update_files, [], restart: :transient)
    send_resp(conn, 202, <<>>)
  end

  get "/" do
    send_file(conn, 200, "static/index.html")
  end

  match _ do
    send_resp(conn, 404, "")
  end
end
