Gem::Specification.new do |s|
  s.name              = "monk"
  s.version           = "1.0.0.beta0"
  s.summary           = "Monk, the glue framework"
  s.description       = "Monk is a glue framework for web development in Ruby. It’s truly modular by relying on the best tool for each job. It’s also pretty fast thanks to Rack and Sinatra."
  s.authors           = ["Damian Janowski", "Michel Martens"]
  s.email             = ["djanowski@dimaion.com", "michel@soveran.com"]
  s.homepage          = "http://monkrb.com"
  s.executables.push("monk")

  s.add_dependency("thor", "~> 0.11")
  s.add_development_dependency("cutest", "~> 0.1")

  s.requirements.push("git")
  s.requirements.push("rvm")

  s.files = ["LICENSE", "README.markdown", "Rakefile", "bin/monk", "lib/monk.rb", "monk.gemspec", "test/commands.rb", "test/helper.rb", "test/monk_add_NAME_REPOSITORY.rb", "test/monk_init_NAME.rb", "test/monk_install.rb", "test/monk_list.rb", "test/monk_rm_NAME.rb", "test/monk_show_NAME.rb"]
end
