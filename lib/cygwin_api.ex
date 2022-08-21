defmodule CygwinApi do
  def get_packages(base) do
    {:ok, response} =
      Finch.build(:get, base <> "x86_64/setup.ini")
      |> Finch.request(FinchClient)

    parse_setup(String.split(response.body, "\n"))
  end

  defp parse_setup_line(line, packages, current, prev) do
    case String.split(line) do
      ["@", name] ->
        cur = Agent.get(current, & &1)

        if cur != nil do
          :ok = Agent.update(packages, &[cur | &1])
        end

        :ok = Agent.update(current, fn _ -> %{:name => name} end)
        :ok = Agent.update(prev, fn _ -> false end)

      ["[prev]"] ->
        :ok = Agent.update(prev, fn _ -> true end)

      ["install:", path, _size, _hash] ->
        if Agent.get(prev, &(!&1)) do
          :ok = Agent.update(current, &Map.put(&1, :path, path))
        end

      ["version:", version] ->
        if Agent.get(prev, &(!&1)) do
          :ok = Agent.update(current, &Map.put(&1, :version, version))
        end

      _ ->
        nil
    end
  end

  defp parse_setup(stream) do
    {:ok, packages} = Agent.start_link(fn -> [] end)
    {:ok, current} = Agent.start_link(fn -> nil end)
    {:ok, prev} = Agent.start_link(fn -> false end)
    :ok = Enum.each(stream, fn line -> parse_setup_line(line, packages, current, prev) end)
    cur = Agent.get(current, & &1)

    if cur != nil do
      :ok = Agent.update(packages, &[cur | &1])
    end

    result = Agent.get(packages, & &1)

    Agent.stop(packages)
    Agent.stop(current)
    Agent.stop(prev)

    result
  end

  def get_files(package, version) do
    {:ok, response} =
      Finch.build(:get, "https://cygwin.com/packages/x86_64/#{package}/#{package}-#{version}")
      |> Finch.request(FinchClient)

    {:ok, document} = Floki.parse_document(response.body)

    document
    |> Floki.find("pre")
    |> Floki.text()
    |> String.split("\n", trim: true)
    |> Stream.map(&String.split/1)
    |> Stream.map(&Enum.fetch!(&1, 3))
    |> Enum.filter(&(String.ends_with?(&1, ".dll") || String.ends_with?(&1, ".exe")))
  end
end
