defmodule PackageRepository do
  use GenServer
  require Logger
  alias Exqlite.Sqlite3

  def start_link(filename) do
    Logger.info("Connecting to database " <> filename)
    GenServer.start_link(__MODULE__, filename, name: __MODULE__)
  end

  def add_package(service, package) do
    GenServer.cast(service, {:add_one, package})
  end

  def add_packages(service, packages) do
    GenServer.cast(service, {:add, packages})
  end

  def delete_package(service, package) do
    GenServer.cast(service, {:delete, package})
  end

  def update_files(service, package, files) do
    GenServer.cast(service, {:update, package, files})
  end

  def set_outdated(service, package) do
    GenServer.cast(service, {:outdate, package})
  end

  def update(service, package, files) do
    GenServer.cast(service, {:update, package, files})
  end

  def get_versions(service) do
    rows = GenServer.call(service, :get_versions)
    Map.new(Stream.map(rows, &List.to_tuple/1))
  end

  def get_outdated(service) do
    rows = GenServer.call(service, :get_outdated)
    Enum.map(rows, &%{name: Enum.fetch!(&1, 0), version: Enum.fetch!(&1, 1)})
  end

  def get_package_for_file(service, file) do
    row = GenServer.call(service, {:get_package_for_file, file})

    %{
      package_name: Enum.fetch!(row, 0),
      package_path: Enum.fetch!(row, 1),
      file_name: Enum.fetch!(row, 2),
      file_path: Enum.fetch!(row, 3)
    }
  end

  def get_packages_for_files(service, files) do
    files = Stream.map(files, &("usr/bin/" <> &1))
    rows = GenServer.call(service, {:get_packages_for_files, files})

    rows
    |> Enum.sort_by(&Enum.fetch!(&1, 0))
    |> Stream.chunk_by(&Enum.fetch!(&1, 0))
    |> Enum.map(fn chunk ->
      %{
        name: Enum.fetch!(hd(chunk), 0),
        path: Enum.fetch!(hd(chunk), 1),
        files: Enum.map(chunk, &%{name: Enum.fetch!(&1, 2), path: Enum.fetch!(&1, 3)})
      }
    end)
  end

  def add_dependencies(service, file, dependencies) do
    GenServer.cast(service, {:add_dependencies, file, dependencies})
  end

  def remove_dependency(service, file, dependency) do
    GenServer.cast(service, {:add_dependencies, file, dependency})
  end

  def get_dependencies(service, files) do
    GenServer.call(service, {:get_dependencies, files}) |> Stream.map(&hd/1)
  end

  def close(service) do
    GenServer.cast(service, :close)
  end

  @impl true
  def init(database) do
    Sqlite3.open(database)
  end

  @impl true
  def handle_cast({:add, packages}, conn) do
    {:ok, statement} = Exqlite.Sqlite3.prepare(conn, "insert into packages values (?,?,?,1)")

    Enum.each(packages, fn pack ->
      Sqlite3.bind(conn, statement, [pack.name, pack.version, pack.path])
      :done = Sqlite3.step(conn, statement)
    end)

    :ok = Sqlite3.release(conn, statement)
    {:noreply, conn}
  end

  @impl true
  def handle_cast({:add_one, package}, conn) do
    execute(conn, "insert into packages values (?,?,?,1)", [
      package.name,
      package.version,
      package.path
    ])

    {:noreply, conn}
  end

  @impl true
  def handle_cast({:delete, package}, conn) do
    execute(conn, "delete from files where package_name = ?", [package])
    execute(conn, "delete from packages where name = ?", [package])
    {:noreply, conn}
  end

  @impl true
  def handle_cast({:update, package, files}, conn) do
    execute(conn, "delete from files where package_name = ?", [package])
    {:ok, statement} = Sqlite3.prepare(conn, "insert into files values ((?1),(?2),(?3))")

    Enum.each(files, fn file ->
      Sqlite3.bind(conn, statement, [file, Path.basename(file), package])
      :done = Sqlite3.step(conn, statement)
    end)

    :ok = Sqlite3.release(conn, statement)
    execute(conn, "update packages set needs_update = 0 where name = ?", [package])
    {:noreply, conn}
  end

  @impl true
  def handle_cast({:outdate, package}, conn) do
    execute(conn, "update packages set version = ?, path = ?, needs_update = 1 where name = ?", [
      package.version,
      package.path,
      package.name
    ])

    {:noreply, conn}
  end

  @impl true
  def handle_cast({:add_dependencies, file, dependencies}, conn) do
    {:ok, statement} = Exqlite.Sqlite3.prepare(conn, "insert into dependencies values (?,?)")

    Enum.each(dependencies, fn dependency ->
      Sqlite3.bind(conn, statement, [file, depndency])
      :done = Sqlite3.step(conn, statement)
    end)

    :ok = Sqlite3.release(conn, statement)
    {:noreply, conn}
  end

  @impl true
  def handle_cast({:remove_dependency, file, dependency}, conn) do
    execute(conn, "delete from dependencies where file = ? and dependency = ?", [file, dependency])

    {:noreply, conn}
  end

  @impl true
  def handle_cast(:close, conn) do
    Sqlite3.close(conn)
    {:noreply, nil}
  end

  @impl true
  def handle_call(:get_versions, _, conn) do
    rows = execute_select(conn, "select name, version from packages", nil)
    {:reply, rows, conn}
  end

  @impl true
  def handle_call(:get_outdated, _, conn) do
    rows = execute_select(conn, "select name, version from packages where needs_update=1", nil)
    {:reply, rows, conn}
  end

  @impl true
  def handle_call({:get_packages_for_files, files}, _, conn) do
    {:ok, statement} =
      Sqlite3.prepare(
        conn,
        "select packages.name, packages.path, files.name, files.path from packages inner join files on packages.name=files.package_name where files.path = (?1)"
      )

    rows =
      Enum.flat_map(files, fn file ->
        :ok = Sqlite3.bind(conn, statement, [file])
        {:ok, row} = Sqlite3.fetch_all(conn, statement)
        row
      end)

    {:reply, rows, conn}
  end

  @impl true
  def handle_call({:get_package_for_file, file}, _, conn) do
    rows =
      execute_select(
        conn,
        "select packages.name, packages.path, files.name, files.path from packages inner join files on packages.name=files.package_name where files.name = (?1)",
        [file]
      )

    {:reply, hd(rows), conn}
  end

  @impl true
  def handle_call({:get_dependencies, files}, _, conn) do
    {:ok, statement} = Sqlite3.prepare(conn, "select dependency from dependencies where file = ?")

    rows =
      Enum.flat_map(files, fn file ->
        :ok = Sqlite3.bind(conn, statement, [file])
        {:ok, res} = Sqlite3.fetch_all(conn, statement)
        res
      end)

    :ok = Sqlite3.release(conn, statement)
    {:reply, rows, conn}
  end

  @impl true
  def terminate(_, conn) do
    Logger.debug("Closing database")

    if conn != nil do
      Sqlite3.close(conn)
    end
  end

  defp execute(conn, sql, args) do
    {:ok, statement} = Sqlite3.prepare(conn, sql)
    :ok = Sqlite3.bind(conn, statement, args)
    :done = Sqlite3.step(conn, statement)
    :ok = Sqlite3.release(conn, statement)
  end

  defp execute_select(conn, sql, args) do
    {:ok, statement} = Sqlite3.prepare(conn, sql)
    :ok = Sqlite3.bind(conn, statement, args)
    {:ok, rows} = Sqlite3.fetch_all(conn, statement)
    :ok = Sqlite3.release(conn, statement)
    rows
  end
end
