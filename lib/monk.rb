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
    if clone(source(options[:skeleton] || "default") || options[:skeleton], target)
      cleanup(target)
      rvmrc appname(target), target
      display_success_banner appname(target)
    else
      say_status(:error, clone_error(target))
    end
  end

  desc "rvmrc", "Create an .rvmrc file"
  def rvmrc(gemset, target = '.', version = '1.9.2')
    key = [version, gemset].join('@')

    say "Generating an .rvmrc file in your project."
    response = ask("Enter gemset name and ruby version (default: `%s`):" % key)

    key = response unless response.to_s.empty?

    create_file File.join(target, '.rvmrc'), "rvm --create use %s\n" % key
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

  def write_monk_config_file
    remove_file(monk_config_file, :verbose => false)
    create_file(monk_config_file, nil, :verbose => false) do
      config = @monk_config || { "default" => "git://github.com/monkrb/skeleton.git" }
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

  def display_success_banner
    say "\n"
    say "=" * 50
    say "-> You have successfully generated #{name}"
    say "=" * 50
    say "\n"
   
    if File.exist?(File.join(target, 'default.gems'))
      say "The skeleton you used comes with a `default.gems` file."
      say "To import the gems just run `rvm gemset import`."
      say "You may also clear out the existing gemset by doing `rvm gemset clear`."
    end
  end

  def appname(target)
    target == '.' ? File.basename(FileUtils.pwd) : target
  end
end
