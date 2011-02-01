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

  desc "help TASK", "Show help for a given TASK"
  def help(*args)
    return super  if args.any?

    say "Usage: #{CMD} <command>"
    max = self.class.all_tasks.map { |_, task| task.usage.size }.max

    if other_tasks.any?
      say ""
      say "Project commands:"
      print_tasks other_tasks, max
    end

    unless in_project?
      say ""
      say "Commands:"
      print_tasks task_categories[:init], max
    end

    if in_project?
      say ""
      say "Dependency commands:"
      print_tasks task_categories[:deps], max
    end

    say ""
    say "Skeleton commands:"
    print_tasks task_categories[:repo], max

    say ""
    say "Misc commands:"
    print_tasks task_categories[:misc], max

    unless in_project?
      say ""
      say "Get started by typing:"
      say "  $ monk init my_project"
      say ""
      say "  See http://www.monkrb.com for more information."
    end
  end

  desc "init NAME [-s SKELETON]", "Start a new project"
  long_desc %{
    Initializes a Monk application of a given name.

    You may use a different skeleton by specifying `-s SKELETON`, where SKELETON refers to the name or URL of the skeleton. If this isn't specified, the default skeleton is used.

    == Examples

    This creates a new Monk/Sinatra application in the directory `myapp`.

        $ monk init myapp

    This creates a new application based on the skeleton in the given git repo.

        $ monk add myskeleton https://github.com/rstacruz/myskeleton.git
        $ monk init myapp -s myskeleton

    You may also specify the URL directly.

        $ monk init myapp -s https://github.com/rstacruz/myskeleton.git
  }
  method_option :skeleton, :type => :string, :aliases => "-s"
  def init(target)
    ensure_rvm
    clone(target)
    cleanup(target)
    create_rvmrc(target)

    say_status :success, "Created #{target}"
  end

  desc "install [--clean]", "Install all project dependencies"
  long_desc %{
    Loads the given gemset name of your project, and installs the gems
    needed by your project.

    If the `--clean` option is given, the gemset is emptied first.

    Gems are specified in the `.gems` file. This is created using
    `#{CMD} lock`.

    The gemset name is then specified in `.rvmrc`, which is created upon
    creating your project with `monk init`.
  }
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

  desc "lock", "Lock gem dependencies into a gem manifest file"
  long_desc %{
    Locks the current gem version dependencies of your project into the gem
    manifest file.

    This creates the `.gems` file for your project, which is then used by
    `monk install`.
  }
  def lock
    run("rvm rvmrc load")
    run("rvm gemset export .gems")
  end

  desc "unpack", "Freeze gem dependencies into vendor/"
  long_desc %{
    Freezes the current gem dependencies of your project into the `vendor/`
    path of your project.

    This allows you to commit the gem contents into your project's repository.
    This way, deploying your project elsewhere would not need `monk install`
    or `gem install` to set up the dependencies.
  }
  def unpack
    run("rvm rvmrc load")
    run("rvm gemset unpack vendor")
  end

  desc "show NAME", "Display info for skeleton NAME"
  def show(name)
    say_status name, source(name) || "repository not found"
  end

  desc "list", "List skeletons"
  def list
    monk_config.keys.sort.each do |key|
      show(key)
    end
  end

  desc "add NAME REPOSITORY", "Add a skeleton"
  def add(name, repository)
    monk_config[name] = repository
    write_monk_config_file
  end

  desc "rm NAME", "Remove a skeleton"
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
      s =  "Error: Monk requires RVM to be installed.\n"
      s << "To install it, run:\n"
      s << "\n"
      s << "    bash < <( curl http://rvm.beginrescueend.com/releases/rvm-install-head )\n"
      s << "\n"
      s << "See http://rvm.beginrescueend.com/ for more information."
      raise Thor::Error, s
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
      :deps => %w(install lock unpack),
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

  def in_project?
    File.exists? 'Thorfile'
  end
end

