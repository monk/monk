require File.expand_path("helper", File.dirname(__FILE__))

# monk init NAME
scope do
  test "fail if the target working directory is not empty" do
    Dir.chdir(root("test", "tmp")) do
      FileUtils.rm_rf("monk-test")
      FileUtils.mkdir("monk-test")

      Dir.chdir("monk-test") do
        FileUtils.touch("foobar")
      end

      out, err = monk("init monk-test")
      assert out.match(/error/)
    end
  end

  test "create a skeleton app in the target directory" do
    Dir.chdir(root("test", "tmp")) do
      FileUtils.rm_rf("monk-test")

      out, err = monk("init monk-test")
      assert out.match(/initialized.* monk-test/)
    end
  end

  test "be able to pull from a url instead of a known skeleton" do
    Dir.chdir(root("test", "tmp")) do
      FileUtils.rm_rf "monk-test"
      out, err = monk("init monk-test --skeleton git://github.com/monkrb/skeleton.git")
      assert out.match(/initialized.* monk-test/)
    end
  end

  test "ask for a gemset name when it already exists" do
    rvm("gemset create monk-test")

    Dir.chdir(root("test", "tmp")) do
      FileUtils.rm_rf("monk-test")
      FileUtils.mkdir("monk-test")

      monk("init monk-test") do |io|
        io.write("1.9.2@custom-monk-test\n")
      end
    end

    assert rvmrc?("custom-monk-test", "monk-test")
    assert gemset?("custom-monk-test")

    rvm("--force gemset delete custom-monk-test")
  end

  test "display readme upon initialization" do
    Dir.chdir(root("test", "tmp")) do
      FileUtils.rm_rf("monk-test")
      FileUtils.mkdir("monk-test")

      out, _ = monk("init monk-test -s git://github.com/monk/experimental.git")

      assert out["monk install"]
      assert out["monk redis"]
      assert out["monk start"]
    end
  end
end

