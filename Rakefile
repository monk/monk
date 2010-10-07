task :test do
  require "cutest"

  Cutest.run(Dir["test/monk_*.rb"])

  `rvm --force gemset delete monk-test`
end

task :default => :test
