defmodule CygwinApiTest do
  use ExUnit.Case, async: true
  import Mox

  test "get_packages" do
    expect(MockHttpClient, :get, fn _ -> File.read!("test/res/test_setup.ini") end)

    result = CygwinApi.get_packages("https://mirror/")

    assert length(result) == 2
    package1 = Enum.find(result, fn p -> p.name == "package1" end)
    assert package1 != nil
    assert package1.version == "1.0.0-1"
    package2 = Enum.find(result, fn p -> p.name == "package2" end)
    assert package2 != nil
    assert package2.version == "3.0.2-3"
  end

  test "get_files" do
    expect(MockHttpClient, :get, fn _ -> File.read!("test/res/test_files.html") end)

    result = CygwinApi.get_files("package1", "1.0.0-1")

    assert MapSet.new(result) ==
             MapSet.new([
               "usr/bin/file3.exe",
               "usr/bin/file4.exe",
               "usr/lib/file5.dll",
               "usr/sbin/file7.exe",
               "usr/sbin/file8.dll"
             ])
  end
end
