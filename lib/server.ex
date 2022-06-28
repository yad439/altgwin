defmodule Server do
  use Plug.Router

  plug(Plug.Logger, log: :debug)
  plug(:auth)
  plug(:match)
  plug(:dispatch)

  defp auth(conn, _) do
    username = System.fetch_env!("AUTH_USERNAME")
    password = System.fetch_env!("AUTH_PASSWORD")
    Plug.BasicAuth.basic_auth(conn, username: username, password: password)
  end

  get "/hello" do
    send_resp(conn, 200, "world")
  end

  get "/download" do
    conn = fetch_query_params(conn)
    archive = Altgwin.prepare_download(conn.params["files"])
    conn = put_resp_content_type(conn, "application/zip")
    send_resp(conn, 200, archive)
  end

  match _ do
    send_resp(conn, 404, "")
  end
end
