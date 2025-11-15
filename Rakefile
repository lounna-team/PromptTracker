require "bundler/setup"

APP_RAKEFILE = File.expand_path("test/dummy/Rakefile", __dir__)
load "rails/tasks/engine.rake"

load "rails/tasks/statistics.rake"

require "bundler/gem_tasks"

# Load RSpec tasks if RSpec is available
begin
  require "rspec/core/rake_task"
  RSpec::Core::RakeTask.new(:spec)
rescue LoadError
  # RSpec not available
end

# Custom task to run both Minitest and RSpec
desc "Run all tests (Minitest + RSpec)"
task :test_all do
  minitest_success = true
  rspec_success = true

  puts "\n" + "=" * 80
  puts "🧪 Running Minitest Suite"
  puts "=" * 80 + "\n"

  # Run Minitest using system command
  minitest_success = system("bundle exec rails test")

  puts "\n" + "=" * 80
  puts "🔬 Running RSpec Suite"
  puts "=" * 80 + "\n"

  # Run RSpec using system command
  rspec_success = system("bundle exec rspec")

  puts "\n" + "=" * 80
  puts "📊 Test Summary"
  puts "=" * 80

  if minitest_success
    puts "Minitest: ✅ PASSED"
  else
    puts "Minitest: ❌ FAILED"
  end

  if rspec_success
    puts "RSpec:    ✅ PASSED"
  else
    puts "RSpec:    ❌ FAILED"
  end

  puts "=" * 80 + "\n"

  if minitest_success && rspec_success
    puts "✅ All tests passed!\n\n"
  else
    puts "❌ Some tests failed!\n\n"
    exit 1
  end
end

# Make test_all the default task
task default: :test_all
