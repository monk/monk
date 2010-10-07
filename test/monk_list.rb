require File.expand_path("helper", File.dirname(__FILE__))

# monk list
scope do
  test "display the configured repositories" do
    out, err = monk("list")
    assert out["default"]
    assert out["http://github.com/monk/experimental.git"]
  end
end
