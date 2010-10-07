require File.expand_path("helper", File.dirname(__FILE__))

prepare do
  FileUtils.rm_rf(TARGET)
end

# monk init NAME
scope do
  test "fail if the target working directory is not empty" do
    FileUtils.mkdir(TARGET)
    FileUtils.touch(TARGET + "/foo")

    out, err = monk("init #{TARGET}")
    assert out.match(/error/)
  end

  test "create a skeleton app in the target directory" do
    out, err = monk("init #{TARGET}")
    assert out.match(/initialized.* #{TARGET}/)
  end

  test "be able to pull from a url instead of a known skeleton" do
    out, err = monk("init #{TARGET} --skeleton http://github.com/monkrb/skeleton.git")
    assert out.match(/initialized.* #{TARGET}/)
  end
end
