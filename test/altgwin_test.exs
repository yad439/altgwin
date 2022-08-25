defmodule AltgwinTest do
  use ExUnit.Case, async: true
  import Mox
  alias Exqlite.Sqlite3

  setup do
    repository =
      start_supervised!({PackageRepository, database: ":memory:", name: PackageRepository})

    _ = start_supervised!({Task.Supervisor, name: TaskSupervisor})
    conn = :sys.get_state(repository)

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

    %{repository: repository}
  end

  test "update_database", %{repository: repo} do
    conn = :sys.get_state(repo)

    :ok =
      Sqlite3.execute(
        conn,
        "insert into packages values ('package1', '1.0.0-1', 'path/to/package1', 0)"
      )

    :ok =
      Sqlite3.execute(
        conn,
        "insert into packages values ('package2', '3.0.0', 'path/to/package2', 0)"
      )

    :ok = Sqlite3.execute(conn, "insert into files values ('path/to/file1', 'file1', 'package1')")
    :ok = Sqlite3.execute(conn, "insert into files values ('path/to/file2', 'file2', 'package1')")
    :ok = Sqlite3.execute(conn, "insert into files values ('path/to/file3', 'file3', 'package2')")
    stub(MockHttpClient, :get, &fake_http_client/1)

    :ok = Altgwin.update_database()
    tasks = Task.Supervisor.children(TaskSupervisor)
    ref = Process.monitor(hd(tasks))
    assert length(tasks) == 1

    receive do
      {:DOWN, ^ref, :process, _, _} -> nil
    end

    _ = :sys.get_state(repo)

    assert execute_select(
             conn,
             "select version, needs_update from packages where name='package1'"
           ) == [["1.0.0-1", 0]]

    assert execute_select(
             conn,
             "select version, needs_update from packages where name='package2'"
           ) == [["3.0.2-3", 0]]

    assert execute_select(conn, "select name from files where package_name='package1'") == [
             ["file1"],
             ["file2"]
           ]

    assert execute_select(conn, "select name from files where package_name='package2'") == [
             ["file3.exe"],
             ["file4.exe"],
             ["file5.dll"],
             ["file7.exe"],
             ["file8.dll"]
           ]
  end

  test "prepare_download", %{repository: repo} do
    conn = :sys.get_state(repo)

    :ok =
      Sqlite3.execute(
        conn,
        "insert into packages values ('package1', '1.0.0-1', 'path/to/test2.tar.bz2', 0)"
      )

    :ok =
      Sqlite3.execute(
        conn,
        "insert into packages values ('package2', '3.0.0', 'path/to/test3.tar.bz2', 0)"
      )

    :ok =
      Sqlite3.execute(
        conn,
        "insert into files values ('usr/bin/file1.exe', 'file1.exe', 'package1')"
      )

    :ok =
      Sqlite3.execute(
        conn,
        "insert into files values ('usr/bin/file2.dll', 'file2.dll', 'package1')"
      )

    :ok =
      Sqlite3.execute(
        conn,
        "insert into files values ('usr/bin/file3.dll', 'file3.dll', 'package2')"
      )

    :ok = Sqlite3.execute(conn, "insert into dependencies values ('file1.exe', 'file2.dll')")
    :ok = Sqlite3.execute(conn, "insert into dependencies values ('file2.dll', 'file3.dll')")

    stub(MockHttpClient, :get, &fake_http_client/1)

    result = Altgwin.prepare_download(["file1.exe"])

    {:ok, files} = :zip.unzip(result, [:memory])

    assert MapSet.new(Enum.map(files, &elem(&1, 0))) ==
             MapSet.new(['file1.exe', 'file2.dll', 'file3.dll'])

    assert elem(Enum.find(files, fn {name, _} -> name == 'file1.exe' end), 1) == "file 1 content"
  end

  defp fake_http_client(url) do
    cond do
      String.contains?(url, "setup.ini") ->
        File.read!("test/res/test_setup.ini")

      String.contains?(url, "https://cygwin.com/packages/") ->
        File.read!("test/res/test_files.html")

      String.contains?(url, "test2.tar.bz2") ->
        File.read!("test/res/test2.tar.bz2")

      String.contains?(url, "test3.tar.bz2") ->
        File.read!("test/res/test3.tar.bz2")
    end
  end

  defp execute_select(conn, query) do
    {:ok, statement} = Sqlite3.prepare(conn, query)
    {:ok, rows} = Sqlite3.fetch_all(conn, statement)
    :ok = Sqlite3.release(conn, statement)
    rows
  end
end
