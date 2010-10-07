require "rubygems"
require "cutest"
require "fileutils"

ROOT = File.expand_path(File.join(File.dirname(__FILE__), ".."))

$:.unshift ROOT

require "test/commands"

include Commands

TARGET = File.expand_path("tmp/monk-test", File.dirname(__FILE__))

def root(*args)
  File.join(ROOT, *args)
end

def monk(args = nil, &block)
  cmd =
    "env MONK_HOME=#{root "test/tmp"} " +
    "ruby -rubygems #{root "bin/monk"} #{args}"

  sh(cmd, &block)
end

def rvm(args = nil)
  sh("rvm #{args}")
end

prepare do
  dot_monk = File.join(ROOT, "test", "tmp", ".monk")

  FileUtils.rm(dot_monk) if File.exist?(dot_monk)
  `rvm gemset use monk-test && rvm --force gemset delete monk-test`
end
