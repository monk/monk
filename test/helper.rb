require "rubygems"
require "cutest"
require "fileutils"

ROOT = File.expand_path(File.join(File.dirname(__FILE__), ".."))

$:.unshift ROOT

require "test/commands"

include Commands

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
  rvm("--force gemset delete monk-test")
end

def rvmrc?(gemset, dir = gemset, version = RUBY_VERSION)
  rvmrc = File.read(root("test", "tmp", dir, ".rvmrc"))
  rvmrc[version] && rvmrc[gemset]
end

def gemset?(gemset)
  out, _ = rvm("gemset list")
  out.match(/^#{gemset}$/)
end

