defmodule Altgwin do
  require Logger

  defp mirror, do: Application.fetch_env!(:altgwin, :mirror)

  def update_database() do
    :ok = detect_outdated(mirror())

    {:ok, _} =
      Task.Supervisor.start_child(TaskSupervisor, fn -> update_files() end, restart: :transient)

    :ok
  end

  def get_dependencies(file), do: PackageRepository.get_dependencies(PackageRepository, [file])

  def remove_dependency(file, dependency) do
    Logger.info(["Removing dependency: ", file, " -> ", dependency])
    :ok = PackageRepository.remove_dependency(PackageRepository, file, dependency)
  end

  def add_dependencies(file, dependencies) do
    Logger.info(["Adding dependencies: ", file, " -> ", Enum.join(dependencies, ", ")])
    :ok = PackageRepository.add_dependencies(PackageRepository, file, dependencies)
  end

  defp detect_outdated(mirror) do
    Logger.info("Updating packages")
    packages = CygwinApi.get_packages(mirror)

    if Enum.empty?(packages) do
      raise RuntimeError, message: "empty package list"
    end

    versions = PackageRepository.get_versions(PackageRepository)

    :ok =
      Enum.each(packages, fn package ->
        case versions[package.name] do
          nil ->
            Logger.info("New package: #{package.name}")
            :ok = PackageRepository.add_package(PackageRepository, package)

          version when version != package.version ->
            Logger.info("Package updated: #{package.name} #{version} -> #{package.version}")
            :ok = PackageRepository.set_outdated(PackageRepository, package)

          _ ->
            nil
        end
      end)

    new_packs = MapSet.new(Stream.map(packages, & &1.name))

    Enum.each(Map.keys(versions), fn package ->
      if !MapSet.member?(new_packs, package) do
        Logger.info("Package deleted: #{package}")
        :ok = PackageRepository.delete_package(PackageRepository, package)
      end
    end)
  end

  defp update_files() do
    Logger.info("Updating files")
    outdated = PackageRepository.get_outdated(PackageRepository)

    Enum.each(outdated, fn package ->
      Logger.debug("Update files of " <> package.name)
      files = CygwinApi.get_files(package.name, package.version)
      :ok = PackageRepository.update_files(PackageRepository, package.name, files)
    end)
  end

  def prepare_download(filenames) do
    all_filenames = get_all_dependencies(filenames)
    Logger.debug(requested_files: filenames, all_files: all_filenames)
    files = get_files(all_filenames, mirror())
    Archives.create_zip(files)
  end

  defp get_files(filenames, mirror) do
    packages = PackageRepository.get_packages_for_files(PackageRepository, filenames)

    got_files =
      packages
      |> Stream.flat_map(fn package -> Stream.map(package.files, & &1.name) end)
      |> MapSet.new()

    Enum.each(filenames, fn file ->
      if !MapSet.member?(got_files, file) do
        Logger.warning(["Did not found package for file ", file])
      end
    end)

    Task.Supervisor.async_stream(
      TaskSupervisor,
      packages,
      fn package ->
        archive = CygwinApi.download_package(mirror, package.path)

        Archives.extract_files(archive, package.path, Stream.map(package.files, & &1.path))
        |> Stream.map(fn {path, data} -> {Path.basename(path), data} end)
      end,
      ordered: false
    )
    |> Enum.flat_map(fn {:ok, f} -> f end)
  end

  defp get_all_dependencies(files) do
    get_all_dependencies(MapSet.new(files), PackageRepository, MapSet.new())
  end

  defp get_all_dependencies(files, repository, done) do
    if Enum.empty?(files) do
      files
    else
      direct = PackageRepository.get_dependencies(repository, files) |> MapSet.new()
      done = MapSet.union(done, files)

      MapSet.union(
        MapSet.union(MapSet.new(files), direct),
        get_all_dependencies(MapSet.difference(direct, done), repository, done)
      )
    end
  end
end
