defmodule ArchivesTest do
  use ExUnit.Case, async: true

  test "extract_files" do
    file = File.read!("test/res/test.tar.bz2")

    result = Archives.extract_files(file, "archive.tar.bz2", ["file1.exe", "file3.dll"])

    assert result == [{"file1.exe", "file 1 content"}, {"file3.dll", "something"}]
  end

  test "create_zip" do
    result = Archives.create_zip([{"file1.exe", "file 1 content"}, {"file3.dll", "something"}])

    {:ok, files} = :zip.unzip(result, [:memory])

    assert Enum.map(files, &elem(&1, 0)) == ['file1.exe', 'file3.dll']
  end
end
