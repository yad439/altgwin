defmodule Altgwin do
  require Logger

  # def main(_) do

  # end

  def detect_outdated(mirror) do
    Logger.info("Updating packages")
    packages = CygwinApi.get_packages(mirror)

    if Enum.empty?(packages) do
      raise RuntimeError, message: "empty package list"
    end

    versions = PackageRepository.get_versions(PackageRepository)

    Enum.each(packages, fn package ->
      case versions[package.name] do
        nil ->
          Logger.info("New package: #{package.name}")
          PackageRepository.add_package(PackageRepository, package)

        version when version != package.version ->
          Logger.info("Package updated: #{package.name} #{version} -> #{package.version}")
          PackageRepository.set_outdated(PackageRepository, package)

        _ ->
          nil
      end
    end)

    new_packs = MapSet.new(Stream.map(packages, & &1.name))

    Enum.each(Map.keys(versions), fn package ->
      if !MapSet.member?(new_packs, package) do
        Logger.info("Package deleted: #{package}")
        PackageRepository.delete_package(PackageRepository, package)
      end
    end)
  end

  def update_files() do
    Logger.info("Updating files")
    outdated = PackageRepository.get_outdated(PackageRepository)

    Enum.each(outdated, fn package ->
      Logger.debug("Update files of " <> package.name)
      files = CygwinApi.get_files(package.name, package.version)
      PackageRepository.update_files(PackageRepository, package.name, files)
    end)
  end

  def prepare_download(filenames) do
    all_filenames = get_dependencies(filenames)
    Logger.debug(requested_files: filenames, all_files: all_filenames)
    files = get_files(all_filenames, Application.fetch_env!(:altgwin, :mirror))
    Archives.create_zip(files)
  end

  defp get_files(filenames, mirror) do
    packages = PackageRepository.get_packages_for_files(PackageRepository, filenames)

    Enum.flat_map(packages, fn package ->
      {:ok, archive} = Finch.build(:get, mirror <> package.path) |> Finch.request(FinchClient)

      Archives.extract_files(archive.body, package.path, Stream.map(package.files, & &1.path))
      |> Stream.map(fn {path, data} -> {Path.basename(to_string(path)), data} end)
    end)
  end

  def get_dependencies(files) do
    get_dependencies(MapSet.new(files), PackageRepository, MapSet.new())
  end

  defp get_dependencies(files, repository, done) do
    if Enum.empty?(files) do
      files
    else
      direct = PackageRepository.get_dependencies(repository, files) |> MapSet.new()
      done = MapSet.union(done, files)

      MapSet.union(
        MapSet.union(MapSet.new(files), direct),
        get_dependencies(MapSet.difference(direct, done), repository, done)
      )
    end
  end
end
