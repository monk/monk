#! /usr/bin/env ruby

require "thor"
require "yaml"

class Monk < Thor
  VERSION = "1.0.0.beta1"
  CMD     = "monk"

  include Thor::Actions

  [:skip, :pretend, :force, :quiet].each do |task|
    class_options.delete task
  end

  def help(*a)
    return super  if a.any?

    say "Usage: #{CMD} <command>"
    max = self.class.all_tasks.map { |_, task| task.usage.size }.max

    say ""
    say "Commands:"
    print_tasks task_categories[:init], max

    say ""
    say "Repository commands:"
    print_tasks task_categories[:repo], max

    say ""
    say "Project commands:"
    print_tasks other_tasks, max

    say ""
    say "Misc commands:"
    print_tasks task_categories[:misc], max

    say ""
    say "Description:"
    say "  Monk makes your Sinatra development life easier."
  end

  desc "init NAME [--skeleton SHORTHAND|URL]", "Initialize a Monk application"
  method_option :skeleton, :type => :string, :aliases => "-s"
  def init(target)
    ensure_rvm
    clone(target)
    cleanup(target)
    create_rvmrc(target)

    say_status :success, "Created #{target}"
  end

  desc "install --clean", "Install all dependencies."
  method_option :clean, :type => :boolean
  def install(manifest = ".gems")
    run("rvm rvmrc load")
    run("rvm --force gemset empty") if options.clean?

    IO.popen("rvm gemset import") do |io|
      until io.eof?
        out = io.readline.gsub(/\(.*?\)/, "")
        say_status :info, out if out =~ /installing|skipping/
      end
    end
  end

  desc "lock", "Lock the current dependencies to the gem manifest file."
  def lock
    run("rvm rvmrc load")
    run("rvm gemset export .gems")
  end

  desc "unpack", "Freeze the current dependencies."
  def unpack
    run("rvm rvmrc load")
    run("rvm gemset unpack vendor")
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

  desc "version", "Show the Monk version"
  def version
    say VERSION
  end

private
  def clone(target)
    say_status :fetching, repository
    system "git clone -q --depth 1 #{repository} #{target}"
    say_status(:error, clone_error(target)) and exit unless $?.success?
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

  def write_monk_config_file(default = "http://github.com/monk/experimental.git")
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

  def say_indented(str)
    say str.gsub(/^/, " " * 14)
  end

  def repository
    source(options[:skeleton] || "default") or options[:skeleton]
  end

  def appname(target)
    target == '.' ? File.basename(Dir.pwd) : target
  end

  def create_rvmrc(target)
    target = Dir.pwd if target == "."
    gemset = File.basename(target)
    key = [RUBY_VERSION, gemset].join('@')

    inside(target) do
      run "rvm --rvmrc --create %s && rvm rvmrc trust" % key
    end
  end

  def print_tasks(tasks, max=nil)
    max ||= tasks.map { |_, task| task.usage.size }.max
    tasks.each do |name, task|
      say "  %-#{max}s  # %s" % [ task.usage, task.description ]
    end
  end

  def categories
    { :init => %w(init),
      :repo => %w(show add rm list),
      :misc => %w(help version)
    }
  end

  def task_categories
    @task_categories ||= begin
      tasks = self.class.all_tasks
      Hash.new.tap { |h|
        categories.each do |cat, names|
          h[cat] = tasks.select { |_, task| names.include?(task.name) }
        end
      }
    end
  end

  def other_tasks
    @other_tasks ||= begin
      taken = task_categories.values.map(&:values).flatten
      self.class.all_tasks.select { |_, task| ! taken.include?(task) }
    end
  end
end

