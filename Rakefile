task :test do
  begin
    require "thor"
    require "cutest"
  rescue LoadError
    puts "! You need `thor` and `cutest` to run the test suite."
    exit
  end

  # Allow running specific tests with TEST=monk_add rake
  spec = ENV['TEST'] ? "*#{ENV['TEST']}*.rb" : "monk_*.rb"
  Cutest.run(Dir["test/#{spec}"])

  if `rvm gemset list` =~ /^monk-test$/
    `rvm gemset use monk-test && rvm --force gemset delete monk-test`
  end
end

task :default => :test
