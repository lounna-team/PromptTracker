# frozen_string_literal: true

RSpec.configure do |config|
  config.before(:suite) do
    # Clean the database before the suite starts
    # This is important when running after Minitest which uses fixtures
    DatabaseCleaner.clean_with(:truncation)
    DatabaseCleaner.strategy = :transaction
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end

  config.after(:suite) do
    # Clean up after all tests complete
    DatabaseCleaner.clean_with(:truncation)
  end
end
