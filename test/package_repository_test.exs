defmodule PackageRepositoryTest do
  use ExUnit.Case, async: true
  alias Exqlite.Sqlite3

  setup do
    repository = start_supervised!({PackageRepository, database: ":memory:", name: :test_repo})
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

  test "add_packages", %{repository: repo} do
    packages = [
      %{name: "package1", version: "1.0.0", path: "path/to/package1"},
      %{name: "package2", version: "0.5", path: "path/to/package2"}
    ]

    res = PackageRepository.add_packages(repo, packages)
    conn = :sys.get_state(repo)

    assert res == :ok

    assert MapSet.new(execute_select(conn, "select name from packages")) ==
             MapSet.new([["package1"], ["package2"]])
  end

  test "delete_package", %{repository: repo} do
    conn = :sys.get_state(repo)

    :ok =
      Sqlite3.execute(
        conn,
        "insert into packages values ('package1', '1.0.0', 'path/to/package1', 1)"
      )

    :ok =
      Sqlite3.execute(
        conn,
        "insert into packages values ('package2', '0.5', 'path/to/package2', 1)"
      )

    res = PackageRepository.delete_package(repo, "package1")
    _ = :sys.get_state(repo)

    assert res == :ok
    assert execute_select(conn, "select name from packages") == [["package2"]]
  end

  test "update_files", %{repository: repo} do
    conn = :sys.get_state(repo)

    :ok =
      Sqlite3.execute(
        conn,
        "insert into packages values ('package1', '1.0.0', 'path/to/package1', 1)"
      )

    :ok =
      Sqlite3.execute(
        conn,
        "insert into packages values ('package2', '0.5', 'path/to/package2', 1)"
      )

    :ok = Sqlite3.execute(conn, "insert into files values ('path/to/file1', 'file1', 'package1')")
    :ok = Sqlite3.execute(conn, "insert into files values ('path/to/file2', 'file2', 'package1')")
    :ok = Sqlite3.execute(conn, "insert into files values ('path/to/file3', 'file3', 'package2')")

    res = PackageRepository.update_files(repo, "package1", ["path/to/file4", "path/to/file5"])
    _ = :sys.get_state(repo)

    assert res == :ok

    assert MapSet.new(execute_select(conn, "select name from files")) ==
             MapSet.new([["file3"], ["file4"], ["file5"]])
  end

  test "set_outdated", %{repository: repo} do
    conn = :sys.get_state(repo)

    :ok =
      Sqlite3.execute(
        conn,
        "insert into packages values ('package1', '1.0.0', 'path/to/package1', 0)"
      )

    :ok =
      Sqlite3.execute(
        conn,
        "insert into packages values ('package2', '0.5', 'path/to/package2', 0)"
      )

    result =
      PackageRepository.set_outdated(repo, %{
        name: "package1",
        version: "1.1.0",
        path: "path/to/package1"
      })

    _ = :sys.get_state(repo)

    assert result == :ok

    assert execute_select(
             conn,
             "select version, needs_update from packages where name = 'package1'"
           ) == [["1.1.0", 1]]
  end

  test "get_versions", %{repository: repo} do
    conn = :sys.get_state(repo)

    :ok =
      Sqlite3.execute(
        conn,
        "insert into packages values ('package1', '1.0.0', 'path/to/package1', 1)"
      )

    :ok =
      Sqlite3.execute(
        conn,
        "insert into packages values ('package2', '0.5', 'path/to/package2', 1)"
      )

    result = PackageRepository.get_versions(repo)

    assert result == %{"package1" => "1.0.0", "package2" => "0.5"}
  end

  test "get_outdated", %{repository: repo} do
    conn = :sys.get_state(repo)

    :ok =
      Sqlite3.execute(
        conn,
        "insert into packages values ('package1', '1.0.0', 'path/to/package1', 1)"
      )

    :ok =
      Sqlite3.execute(
        conn,
        "insert into packages values ('package2', '0.5', 'path/to/package2', 0)"
      )

    result = PackageRepository.get_outdated(repo)

    assert result == [%{name: "package1", version: "1.0.0"}]
  end

  test "get_packages_for_files", %{repository: repo} do
    conn = :sys.get_state(repo)

    :ok =
      Sqlite3.execute(
        conn,
        "insert into packages values ('package1', '1.0.0', 'path/to/package1', 1)"
      )

    :ok =
      Sqlite3.execute(
        conn,
        "insert into packages values ('package2', '0.5', 'path/to/package2', 0)"
      )

    :ok = Sqlite3.execute(conn, "insert into files values ('usr/bin/file1', 'file1', 'package1')")
    :ok = Sqlite3.execute(conn, "insert into files values ('usr/bin/file2', 'file2', 'package1')")
    :ok = Sqlite3.execute(conn, "insert into files values ('usr/bin/file3', 'file3', 'package2')")

    result = PackageRepository.get_packages_for_files(repo, ["file1", "file2", "file3"])

    assert result == [
             %{
               name: "package1",
               path: "path/to/package1",
               files: [
                 %{name: "file1", path: "usr/bin/file1"},
                 %{name: "file2", path: "usr/bin/file2"}
               ]
             },
             %{
               name: "package2",
               path: "path/to/package2",
               files: [%{name: "file3", path: "usr/bin/file3"}]
             }
           ]
  end

  test "add_dependencies", %{repository: repo} do
    result = PackageRepository.add_dependencies(repo, "file1", ["file2", "file3"])
    assert result == :ok

    conn = :sys.get_state(repo)

    assert execute_select(conn, "select * from dependencies") == [
             ["file1", "file2"],
             ["file1", "file3"]
           ]
  end

  test "remove_dependency", %{repository: repo} do
    conn = :sys.get_state(repo)

    :ok =
      Sqlite3.execute(
        conn,
        "insert into dependencies values ('file1', 'file2')"
      )

    :ok =
      Sqlite3.execute(
        conn,
        "insert into dependencies values ('file1', 'file3')"
      )

    result = PackageRepository.remove_dependency(repo, "file1", "file2")
    assert result == :ok

    _ = :sys.get_state(repo)

    assert execute_select(conn, "select * from dependencies") == [["file1", "file3"]]
  end

  test "get_dependencies", %{repository: repo} do
    conn = :sys.get_state(repo)

    :ok =
      Sqlite3.execute(
        conn,
        "insert into dependencies values ('file1', 'file2')"
      )

    :ok =
      Sqlite3.execute(
        conn,
        "insert into dependencies values ('file1', 'file3')"
      )

    :ok =
      Sqlite3.execute(
        conn,
        "insert into dependencies values ('file4', 'file5')"
      )

    result = PackageRepository.get_dependencies(repo, ["file1", "file4"])
    assert Enum.to_list(result) == ["file2", "file3", "file5"]
  end

  defp execute_select(conn, query) do
    {:ok, statement} = Sqlite3.prepare(conn, query)
    {:ok, rows} = Sqlite3.fetch_all(conn, statement)
    :ok = Sqlite3.release(conn, statement)
    rows
  end
end
