defmodule Altgwin do
  use Application
  require Logger

  @impl true
  def start(_, args) do
    main(args)
    Supervisor.start_link([], strategy: :one_for_one)
  end

  def main(_) do
    {:ok, _} = Finch.start_link(name: FinchClient)
    {:ok, db} = PackageRepository.start_link("packages.db")

    packages = CygwinApi.parse_setup(File.stream!("setup.ini"))

    np =
      Enum.map(Enum.take(packages, 20), fn p ->
        Map.put(p, :files, Cygwin.get_files(p.name, p.version))
      end)

    IO.inspect(Enum.at(np, 15))

    {:ok, dt} =
      Finch.build(:get, "https://mirror.easyname.at/cygwin/" <> Enum.at(np, 15).path)
      |> Finch.request(FinchClient)

    dc = Archives.decompress_external("xz", dt.body)
    # IO.inspect(dc)
    # IO.inspect(:erl_tar.table({:binary,dc}))
    IO.inspect(Archives.extract_tar(dc, ["usr/bin/cygznc-1.8.2.dll", "usr/bin/znc.exe"]))
    nil
  end

  def detect_outdated(mirror, repository) do
    packages = CygwinApi.get_packages(mirror)

    if Enum.empty?(packages) do
      raise RuntimeError, message: "empty package list"
    end

    versions = PackageRepository.get_versions(repository)

    Enum.each(packages, fn package ->
      case versions[package.name] do
        nil ->
          Logger.info("New package: #{package.name}")
          PackageRepository.add_package(repository, package)

        version when version != package.version ->
          Logger.info("Package updated: #{package.name} #{version} -> #{package.version}")
          PackageRepository.set_outdated(repository, package)

        _ ->
          nil
      end
    end)

    new_packs = MapSet.new(Stream.map(packages, & &1.name))

    Enum.each(Map.keys(versions), fn package ->
      if !MapSet.member?(new_packs, package) do
        Logger.info("Package deleted: #{package}")
        PackageRepository.delete_package(repository, package)
      end
    end)
  end

  def update_files(repository) do
    outdated = PackageRepository.get_outdated(repository)

    Enum.each(outdated, fn package ->
      Logger.debug("Update files of " <> package.name)
      files = CygwinApi.get_files(package.name, package.version)
      PackageRepository.update_files(repository, package.name, files)
    end)
  end

  def get_files(filenames, mirror, repository) do
    packages =
      Stream.map(filenames, &PackageRepository.get_package_for_file(repository, &1))
      |> Stream.chunk_by(& &1.package_name)
      |> Stream.map(
        &%{
          name: hd(&1).package_name,
          path: hd(&1).package_path,
          files: Enum.map(&1, fn fl -> %{name: fl.file_name, path: fl.file_path} end)
        }
      )

    Enum.flat_map(packages, fn package ->
      {:ok, archive} = Finch.build(:get, mirror <> package.path) |> Finch.request(FinchClient)

      Archives.extract_files(archive.body, package.path, Stream.map(package.files, & &1.path))
      |> Stream.map(fn {path, data} -> {Path.basename(to_string(path)), data} end)
    end)
  end

  def get_dependencies(files,repository) do
    get_dependencies(MapSet.new(files),repository,MapSet.new())
  end

  defp get_dependencies(files,repository, done) do
    if Enum.empty?(files) do
      files
    else
      direct=PackageRepository.get_dependencies(repository,files) |> MapSet.new()
      done=MapSet.union(done,files)
      MapSet.union(MapSet.union(MapSet.new(files),direct),get_dependencies(MapSet.difference(direct,done),done)
    end
  end
end
