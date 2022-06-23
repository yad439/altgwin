defmodule Archives do
  def extract_files(archive, name, files) do
    extract_tar(decompress(archive, Path.extname(name)), files)
  end

  def decompress(data, extension) do
    case extension do
      ".bz2" -> decompress_external("bzip2", data, extension)
      ".xz" -> decompress_external("xz", data, extension)
      ".zst" -> decompress_external("zstd", data, extension)
    end
  end

  def decompress_external(exe, data, extension) do
    {:ok, temp_file, temp_path} = Temp.open(suffix: extension)
    IO.binwrite(temp_file, data)
    File.close(temp_file)
    port = Port.open({:spawn, exe <> " -d -c " <> temp_path}, [:binary])
    Port.monitor(port)
    result = recieve_external(port, <<>>)
    File.rm(temp_path)
    result
  end

  # def decompress_external2(exe,data) do
  # 	port=Port.open({:spawn,exe<>" -d -"},[:binary])
  # 	# Port.monitor(port)
  # 	Port.command(port,data)
  # 	# Port.close(port)
  # 	# send(port,{self(),:close})
  # 	recieve_external(port,<<>>)
  # end

  def extract_tar(archive, files) do
    {:ok, result} =
      :erl_tar.extract({:binary, archive}, [{:files, Enum.map(files, &to_charlist/1)}, :memory])

    result
  end

  def create_zip(files) do
    {:ok, {_, data}} =
      :zip.zip("arc.zip", Enum.map(files, fn {name, data} -> {to_charlist(name), data} end), [
        :memory
      ])

    data
  end

  defp recieve_external(port, data) do
    receive do
      {^port, {:data, msg}} ->
        recieve_external(port, data <> msg)

      {:DOWN, _, :port, ^port, _} ->
        data
    end
  end
end
