defmodule Archives do
  require Logger

  def extract_files(archive, name, files) do
    extract_tar(decompress(archive, Path.extname(name)), files)
  end

  defp decompress(data, extension) do
    case extension do
      ".bz2" -> decompress_external("bzip2", data, extension)
      ".xz" -> decompress_external("xz", data, extension)
      ".zst" -> decompress_external("zstd", data, extension)
    end
  end

  defp decompress_external(exe, data, extension) do
    {:ok, temp_file, temp_path} = Temp.open(%{suffix: extension})
    :ok = IO.binwrite(temp_file, data)
    :ok = File.close(temp_file)
    port = Port.open({:spawn, exe <> " -d -c " <> temp_path}, [:binary])
    Port.monitor(port)
    result = receive_external(port, <<>>)
    :ok = File.rm(temp_path)
    result
  end

  defp extract_tar(archive, files) do
    {:ok, result} =
      :erl_tar.extract({:binary, archive}, [{:files, Enum.map(files, &to_charlist/1)}, :memory])

    result =
      for {path, data} <- result do
        {to_string(path), data}
      end

    if MapSet.new(Stream.map(result, &elem(&1, 0))) != MapSet.new(files) do
      Logger.error("Could not extract all files from archive")
    end

    result
  end

  def create_zip(files) do
    {:ok, {_, data}} =
      :zip.zip('', Enum.map(files, fn {name, data} -> {to_charlist(name), data} end), [:memory])

    data
  end

  defp receive_external(port, data) do
    receive do
      {^port, {:data, msg}} ->
        receive_external(port, data <> msg)

      {:DOWN, _, :port, ^port, _} ->
        data
    end
  end
end
