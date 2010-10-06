#! /usr/bin/env ruby

require "thor"
require "yaml"

class Monk < Thor
  include Thor::Actions

  [:skip, :pretend, :force, :quiet].each do |task|
    class_options.delete task
  end

  desc "init", "Initialize a Monk application"
  method_option :skeleton, :type => :string, :aliases => "-s"
  def init(target = ".")
    ensure_rvm

    repo = source(options[:skeleton] || "default") || options[:skeleton]

    if clone(repo, target)
      cleanup(target)
      rvmrc appname(target), target
    else
      say_status(:error, clone_error(target))
    end
  end

  desc "rvmrc GEMSET [TARGET] [VERSION]", "Create an .rvmrc file"
  def rvmrc(gemset, target = ".", version = RUBY_VERSION)
    key = [version, gemset].join('@')

    if gemset_exists?(gemset)
      response = ask("Enter gemset and Ruby version (default: `%s`):" % key)
      key = response unless response.to_s.empty?
    end

    inside(target) do
      run "rvm --rvmrc --create %s && rvm rvmrc trust" % key
    end
  end

  desc "install --clean", "Install all dependencies."
  method_option :clean, :type => :boolean
  def install(manifest = ".gems")
    run("rvm rvmrc load")
    run("rvm --force gemset empty") if options.clean?

    File.read(manifest).split("\n").each do |gem|
      `gem install #{gem}`
    end
  end

  desc "lock", "Lock the current dependencies to the gem manifest file."
  def lock
    run("rvm gemset export .gems")
    gems = File.read(".gems")
    remove_file(".gems", :verbose => false)
    create_file(".gems", nil, :verbose => false) do
      gems.split("\n").
        reject { |line| line.start_with?("#") }.
        map    { |line| line.gsub(/-v(.*?)$/, "--version \\1") }.
        join("\n") + "\n"
    end
  end

  desc "unpack", "Freeze the current dependencies."
  def unpack
    run("rvm gemset unpack")
  end

  desc "vendor NAME", "Vendor a github repo, e.g. soveran/ohm."
  method_option :force, :type => :boolean
  def vendor(repo)
    repo   = "http://github.com/#{repo}.git" unless repo =~ %r{^[a-z]+://}
    name   = repo.split("/").last.gsub(/\.git$/, "")
    target = "vendor/gems/#{name}"

    if File.exist?(target)
      if not options.force?
        say_status(:error, "#{target} already exists. Use --force to remove.")
        exit
      else
        FileUtils.rm_r(target)
      end
    end

    inside("vendor/gems") do
      run "git clone #{repo} -q --depth 1"
    end

    cleanup(target)
  end

  desc "show NAME", "Display the repository address for NAME"
  def show(name)
    say_status name, source(name) || "repository not found"
  end

  desc "list", "Lists the configured repositories"
  def list
    monk_config.keys.sort.each do |key|
      show(key)
    end
  end

  desc "add NAME REPOSITORY", "Add the repository to the configuration file"
  def add(name, repository)
    monk_config[name] = repository
    write_monk_config_file
  end

  desc "rm NAME", "Remove the repository from the configuration file"
  def rm(name)
    monk_config.delete(name)
    write_monk_config_file
  end

private
  def clone(source, target)
    if Dir["#{target}/*"].empty?
      say_status :fetching, source
      system "git clone -q --depth 1 #{source} #{target}"
      $?.success?
    end
  end

  def cleanup(target)
    inside(target) { remove_file ".git" }
    say_status :initialized, target
  end

  def source(name = "default")
    monk_config[name]
  end

  def monk_config_file
    @monk_config_file ||= File.join(monk_home, ".monk")
  end

  def monk_config
    @monk_config ||= begin
      write_monk_config_file unless File.exists?(monk_config_file)
      YAML.load_file(monk_config_file)
    end
  end

  def write_monk_config_file(default = "git://github.com/monkrb/skeleton.git")
    remove_file(monk_config_file, :verbose => false)
    create_file(monk_config_file, nil, :verbose => false) do
      config = @monk_config || { "default" => default }
      config.to_yaml
    end
  end

  def self.source_root
    "."
  end

  def clone_error(target)
    "Couldn't clone repository into target directory '#{target}'. " +
    "You must have git installed and the target directory must be empty."
  end

  def monk_home
    ENV["MONK_HOME"] || File.join(Thor::Util.user_home)
  end

  def appname(target)
    target == '.' ? File.basename(FileUtils.pwd) : target
  end

  def vendored?(lib, version)
    File.exist?("./vendor/gems/#{lib}-#{version}")
  end

  def ensure_rvm
    begin
      `rvm`
    rescue Errno::ENOENT
      install = "bash < <( curl http://rvm.beginrescueend.com/releases/rvm-install-head )"
      say_status :error, "Monk requires RVM to be installed."
      say_status :hint,  "To install it, run: #{install}"
      exit
    end
  end

  def gemset_exists?(gemset)
    `rvm gemset list`.split("\n").include?(gemset)
  end

  def say_indented(str)
    say str.gsub(/^/, " " * 14)
  end
end

