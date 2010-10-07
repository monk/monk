require File.expand_path("helper", File.dirname(__FILE__))

prepare do
  FileUtils.rm_rf(TARGET)
end

test "installs the gems listed in the manifest" do
  monk("init #{TARGET} --skeleton git://github.com/cyx/empty.git")

  FileUtils.cd(TARGET) do
    monk("install")

    assert `gem list` =~ /batch/
    assert `gem list` =~ /cutest/
  end
end
