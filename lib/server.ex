defmodule Server do
  use Plug.Router

  plug(Plug.Logger, log: :debug)
  plug(Plug.Static, at: "/static", from: "static")
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
    files = conn.params["files"]

    if is_list(files) && Enum.each(files, &is_bitstring/1) do
      archive = Altgwin.prepare_download(files)
      conn = put_resp_content_type(conn, "application/zip")
      send_resp(conn, 200, archive)
    else
      send_resp(conn, 400, <<>>)
    end
  end

  get "/dependencies" do
    file = conn.params["file"]

    if is_bitstring(file) do
      deps = Altgwin.get_dependencies(file)
      send_resp(conn, 200, Enum.join(deps, "\n"))
    else
      send_resp(conn, 400, <<>>)
    end
  end

  put "/dependencies" do
    file = conn.params["file"]
    dependencies = conn.params["dependencies"]

    if is_bitstring(file) && is_list(dependencies) && Enum.each(dependencies, &is_bitstring/1) do
      :ok = Altgwin.add_dependencies(file, dependencies)
      send_resp(conn, 201, <<>>)
    else
      send_resp(conn, 400, <<>>)
    end
  end

  delete "/dependencies" do
    file = conn.params["file"]
    dependency = conn.params["dependency"]

    if is_bitstring(file) && is_bitstring(dependency) do
      :ok = Altgwin.remove_dependency(file, dependency)

      send_resp(conn, 204, <<>>)
    else
      send_resp(conn, 400, <<>>)
    end
  end

  post "/update" do
    :ok = Altgwin.update_database()
    send_resp(conn, 202, <<>>)
  end

  get "/" do
    send_file(conn, 200, "static/index.html")
  end

  match _ do
    send_resp(conn, 404, "")
  end
end
