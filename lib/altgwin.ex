defmodule Altgwin do
  use Application

  @impl true
  def start(_, args) do
    main(args)
    Supervisor.start_link([], strategy: :one_for_one)
  end

  def main(_) do
    {:ok, _} = Finch.start_link(name: FinchClient)
    {:ok, db} =Repository.start_link("packages.db")

    packages = Cygwin.parse_setup(File.stream!("setup.ini"))

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

  def update_files(repository) do
    outdated = Repository.get_outdated(repository)

    Enum.each(outdated, fn package ->
      IO.inspect(package.name)
      files = Cygwin.get_files(package.name,package.version)
      Repository.update_files(repository,package.name,files)
    end)
  end
end
