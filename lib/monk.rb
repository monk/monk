#! /usr/bin/env ruby

require "thor"
require "yaml"
require "fileutils"

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
      say "\nProject commands:"
      print_tasks other_tasks, max
    end

    if in_project?
      say "\nDependency commands:"
      print_tasks task_categories[:deps], max
    else
      say "\nCommands:"
      print_tasks task_categories[:init], max
      say "\nSkeleton commands:"
      print_tasks task_categories[:repo], max
    end

    say "\nMisc commands:"
    print_tasks task_categories[:misc], max

    unless in_project?
      say "\nGet started by typing:"
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
    if File.exists?(target) && !Dir[File.join(target, '*')].empty?
      s =  "Error: path `#{target}` already exists.\n"
      s << "Run `#{CMD} init` into a different path, or delete the existing `#{target}` first."
      raise Thor::Error, s
    end

    ensure_rvm
    clone(target)
    cleanup(target)
    create_rvmrc(target)
    #show_tree(target)

    say ""
    say "Success! You've created a new Sinatra project in `#{target}`."
    say "Get started now by typing:"
    say ""
    say "    $ cd #{target}"
    say "    $ monk install"
    say "    $ monk start"
    say ""
    say "...then visit http://localhost:4567."
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
    return  unless File.file?(manifest)

    run("rvm rvmrc load")
    run("rvm --force gemset empty") if options.clean?

    cmd = "rvm gemset import"
    say_status :run, cmd
    IO.popen(cmd) do |io|
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
    keys = monk_config.keys.sort
    max  = keys.map(&:size).max

    return  unless keys.any?

    tip "Available skeletons:"
    tip ""

    keys.each do |key|
      say "  %-#{max}s     # %s" % [ key, source(key) ]
    end

    tip ""
    tip "Use `#{CMD} init APPNAME -s SKELETON` to create a project using the given skeleton."
  end

  desc "add NAME REPOSITORY", "Add a skeleton"
  def add(name, repository)
    exists = monk_config.keys.include?(name)
    monk_config[name] = repository
    write_monk_config_file

    if exists
      tip "Updated skeleton `#{name}`."
    else
      tip "Added skeleton `#{name}`."
    end
    tip "Create a new project using this skeleton with `#{CMD} init APPNAME -s #{name}`."
  end

  desc "rm NAME", "Remove a skeleton"
  def rm(name)
    unless monk_config.keys.include?(name)
      tip "Skeleton `#{name}` not found."
      tip "Type `#{CMD} list` for a list of defined skeletons."
      return
    end

    monk_config.delete(name)
    write_monk_config_file

    tip "Removed skeleton `#{name}`."
  end

  desc "purge", "Purge the skeleton cache"
  long_desc %{
    Purges Monk's cache of skeleton files.

    Everytime `#{CMD} init` is invoked, Monk automatically stores the
    skeleton's files in a cache. This command will clear that cache.
  }
  def purge
    remove_file cache_path
    say "Monk's skeleton cache has been cleared."
  end

  desc "version", "Show the Monk version"
  def version
    say "Monk #{VERSION}"
  end

private
  def clone(target)
    repo = cached_repository
    say_status :create, "#{target}/".squeeze('/')
    FileUtils.cp_r repo, target
    say_status(:error, clone_error(target)) and exit unless $?.success?
  end

  def cleanup(target)
    inside(target) { remove_file ".git" }
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

  def cache_path
    File.expand_path(File.join('~', '.cache', 'monk'))
  end

  def cached_repository
    # If it's local, no need to cache
    return repository  if File.directory?(repository)

    dir = File.join(cache_path, File.basename(options[:skeleton] || "default"))
    return dir  if File.directory?(dir)

    say_status :fetch, repository
    say_status nil, '(This only has to be done once. Please wait...)'

    FileUtils.mkdir_p dir
    system "git clone -q --depth 1 #{repository} #{dir}"
    say_status(:error, clone_error(target)) and exit unless $?.success?

    dir
  end

  def appname(target)
    target == '.' ? File.basename(Dir.pwd) : target
  end

  def create_rvmrc(target)
    target = Dir.pwd if target == "."
    gemset = File.basename(target)
    key = [RUBY_VERSION, gemset].join('@')

    inside(target) do
      run "rvm --rvmrc --create #{key} && rvm rvmrc trust"
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
      :repo => %w(show add rm list purge),
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

  def tip(str)
    $stderr.write "#{str}\n"
  end
end

