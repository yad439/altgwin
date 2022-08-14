defmodule PackageRepositoryTest do
  use ExUnit.Case, async: true
  alias Exqlite.Sqlite3

  setup do
    {:ok, conn} = Sqlite3.open(":memory:")

    :ok =
      Sqlite3.execute(
        conn,
        "create table packages (name text primary key, version text not null, path text not null, needs_update integer not null default 1)"
      )

    :ok =
      Sqlite3.execute(
        conn,
        "create table files (path text not null, name text not null, package_name text not null)"
      )

    :ok =
      Sqlite3.execute(
        conn,
        "create table dependencies (file text not null, dependency text not null)"
      )

    %{conn: conn}
  end

  test ":add handler adds packages", %{conn: conn} do
    packages = [
      %{name: "package1", version: "1.0.0", path: "path/to/package1"},
      %{name: "package2", version: "0.5", path: "path/to/package2"}
    ]

    res = PackageRepository.handle_cast({:add, packages}, conn)

    assert res == {:noreply, conn}
    assert execute_select(conn, "select name from packages") == [["package1"], ["package2"]]
  end

  defp execute_select(conn, query) do
    {:ok, statement} = Sqlite3.prepare(conn, query)
    {:ok, rows} = Sqlite3.fetch_all(conn, statement)
    :ok = Sqlite3.release(conn, statement)
    rows
  end
end
