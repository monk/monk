task :test do
  begin
    require "thor"
    require "cutest"
  rescue LoadError
    puts "! You need `thor` and `cutest` to run the test suite."
    exit
  end

  Cutest.run(Dir["test/monk_*.rb"])

  if `rvm gemset list` =~ /^monk-test$/
    `rvm gemset use monk-test && rvm --force gemset delete monk-test`
  end
end

task :default => :test