# Feature 3: YAML-Based Test Declarations

## 📋 Overview

Extend the existing YAML prompt file format to support test declarations, allowing developers to:
- Define tests alongside prompt definitions in YAML files
- Version control tests with prompts in Git
- Sync tests automatically from YAML to database
- Run tests as part of CI/CD pipelines
- Maintain test-driven development workflow

## 🎯 Goals

1. **Co-locate tests with prompts** - Keep tests near the code they test
2. **Version control tests** - Track test changes in Git
3. **Enable TDD workflow** - Write tests before changing prompts
4. **Simplify test creation** - Define tests in familiar YAML format
5. **Support CI/CD** - Auto-sync and run tests in pipelines

## 🏗️ Architecture

### YAML File Structure

Extend existing prompt YAML files to include a `tests` section:

```yaml
# app/prompts/support/greeting.yml
name: customer_support_greeting
description: Initial greeting for customer support interactions
category: support
tags:
  - customer-facing
  - greeting

template: |
  Hi {{customer_name}}! Thanks for contacting us.
  I'm here to help with your {{issue_category}} question.
  What's going on?

variables:
  - name: customer_name
    type: string
    required: true
  - name: issue_category
    type: string
    required: true

model_config:
  temperature: 0.7
  max_tokens: 120

# NEW: Tests section
tests:
  - name: greeting_premium_user
    description: Test greeting for premium user with billing issue
    enabled: true
    tags: [smoke, regression]

    variables:
      customer_name: "Alice Johnson"
      issue_category: "billing"

    model_config:
      provider: openai
      model: gpt-4
      temperature: 0.7

    assertions:
      # Pattern matching
      contains:
        - "Alice"
        - "billing"

      # Regex patterns
      matches:
        - "Hi \\w+!"

      # Negative assertions
      not_contains:
        - "error"
        - "sorry"

    evaluators:
      - evaluator: length_check
        config:
          min_length: 20
          max_length: 200
        threshold: 80

      - evaluator: keyword_check
        config:
          required_keywords: ["help", "question"]
          forbidden_keywords: ["problem", "issue"]
        threshold: 100

  - name: greeting_basic_user
    description: Test greeting for basic user with technical issue
    enabled: true
    tags: [regression]

    variables:
      customer_name: "Bob Smith"
      issue_category: "technical"

    model_config:
      provider: openai
      model: gpt-3.5-turbo
      temperature: 0.7

    assertions:
      contains:
        - "Bob"
        - "technical"

    evaluators:
      - evaluator: length_check
        config:
          min_length: 20
          max_length: 200
        threshold: 80

# Test suites can also be defined
test_suites:
  - name: greeting_smoke_tests
    description: Quick smoke tests for greeting prompt
    tags: [smoke]
    tests:
      - greeting_premium_user
      - greeting_basic_user
```

### Alternative: Separate Test Files

For complex test scenarios, support separate test files:

```yaml
# app/prompts/support/greeting.tests.yml
prompt: customer_support_greeting

tests:
  - name: greeting_edge_case_long_name
    description: Test with very long customer name
    variables:
      customer_name: "Alexander Maximilian Christopher Wellington III"
      issue_category: "account"

    assertions:
      max_length: 200

    evaluators:
      - evaluator: length_check
        threshold: 80
```

## 🔧 Implementation Plan

### Phase 1: YAML Schema Extension (Week 1)

**Tasks:**
1. Update `PromptFile` to parse `tests` section
2. Add validation for test definitions
3. Create `PromptTestFile` class for separate test files
4. Update schema documentation
5. Write comprehensive tests

**Files to Modify:**
- `app/models/prompt_tracker/prompt_file.rb`

**Files to Create:**
- `app/models/prompt_tracker/prompt_test_file.rb`
- `spec/models/prompt_tracker/prompt_test_file_spec.rb`

**PromptFile Extension:**
```ruby
# app/models/prompt_tracker/prompt_file.rb
module PromptTracker
  class PromptFile
    # Add tests to optional fields
    OPTIONAL_FIELDS = %w[
      description category tags variables model_config notes
      tests test_suites
    ].freeze

    # Parse tests from YAML
    def tests
      @data['tests'] || []
    end

    # Parse test suites from YAML
    def test_suites
      @data['test_suites'] || []
    end

    # Validate tests section
    def validate_tests
      return if tests.blank?

      tests.each_with_index do |test_def, index|
        validate_test_definition(test_def, index)
      end
    end

    private

    def validate_test_definition(test_def, index)
      # Required fields
      unless test_def['name'].present?
        @errors << "Test ##{index + 1}: name is required"
      end

      unless test_def['variables'].is_a?(Hash)
        @errors << "Test '#{test_def['name']}': variables must be a hash"
      end

      # Validate evaluators
      if test_def['evaluators'].present?
        unless test_def['evaluators'].is_a?(Array)
          @errors << "Test '#{test_def['name']}': evaluators must be an array"
        end
      end

      # Validate assertions
      if test_def['assertions'].present?
        validate_assertions(test_def['assertions'], test_def['name'])
      end
    end

    def validate_assertions(assertions, test_name)
      valid_keys = %w[contains not_contains matches not_matches min_length max_length]

      assertions.each_key do |key|
        unless valid_keys.include?(key)
          @errors << "Test '#{test_name}': unknown assertion type '#{key}'"
        end
      end
    end
  end
end
```

**PromptTestFile Class:**
```ruby
# app/models/prompt_tracker/prompt_test_file.rb
module PromptTracker
  class PromptTestFile
    attr_reader :path, :errors

    def initialize(path)
      @path = path
      @errors = []
      @data = nil
      @parsed = false
    end

    def valid?
      parse unless @parsed
      @errors.empty?
    end

    def prompt_name
      @data['prompt']
    end

    def tests
      @data['tests'] || []
    end

    def test_suites
      @data['test_suites'] || []
    end

    private

    def parse
      @parsed = true
      @errors = []

      unless File.exist?(@path)
        @errors << "File does not exist: #{@path}"
        return
      end

      begin
        @data = YAML.load_file(@path)
      rescue Psych::SyntaxError => e
        @errors << "Invalid YAML syntax: #{e.message}"
        return
      end

      validate_structure
    end

    def validate_structure
      unless @data['prompt'].present?
        @errors << "prompt field is required in test file"
      end

      unless @data['tests'].is_a?(Array)
        @errors << "tests must be an array"
      end
    end
  end
end
```

### Phase 2: Test Sync Service (Week 1-2)

**Tasks:**
1. Create `PromptTestSyncService`
2. Sync tests from YAML to database
3. Handle test updates and deletions
4. Integrate with existing `FileSyncService`
5. Write comprehensive tests

**Files to Create:**
- `app/services/prompt_tracker/prompt_test_sync_service.rb`
- `spec/services/prompt_tracker/prompt_test_sync_service_spec.rb`

**Service Implementation:**
```ruby
# app/services/prompt_tracker/prompt_test_sync_service.rb
module PromptTracker
  class PromptTestSyncService
    attr_reader :prompt, :test_definitions

    def initialize(prompt, test_definitions)
      @prompt = prompt
      @test_definitions = test_definitions
    end

    # Sync all tests from YAML to database
    def self.sync(prompt, test_definitions)
      new(prompt, test_definitions).sync
    end

    def sync
      results = {
        created: 0,
        updated: 0,
        skipped: 0,
        errors: []
      }

      test_definitions.each do |test_def|
        result = sync_test(test_def)

        case result[:action]
        when :created
          results[:created] += 1
        when :updated
          results[:updated] += 1
        when :skipped
          results[:skipped] += 1
        when :error
          results[:errors] << result[:error]
        end
      end

      # Clean up tests that are no longer in YAML
      cleanup_removed_tests

      results
    end

    private

    def sync_test(test_def)
      test = prompt.prompt_tests.find_or_initialize_by(name: test_def['name'])

      # Check if test needs updating
      if test.persisted? && !test_changed?(test, test_def)
        return { action: :skipped, test: test }
      end

      # Update test attributes
      test.assign_attributes(
        description: test_def['description'],
        template_variables: test_def['variables'] || {},
        expected_output: test_def['expected_output'],
        expected_patterns: extract_patterns(test_def['assertions']),
        model_config: test_def['model_config'] || {},
        evaluator_configs: test_def['evaluators'] || [],
        enabled: test_def.fetch('enabled', true),
        tags: test_def['tags'] || []
      )

      if test.save
        action = test.previously_new_record? ? :created : :updated
        { action: action, test: test }
      else
        { action: :error, error: test.errors.full_messages.join(', ') }
      end
    rescue => e
      { action: :error, error: e.message }
    end

    def test_changed?(test, test_def)
      # Compare relevant fields to detect changes
      test.description != test_def['description'] ||
        test.template_variables != (test_def['variables'] || {}) ||
        test.model_config != (test_def['model_config'] || {}) ||
        test.evaluator_configs != (test_def['evaluators'] || [])
    end

    def extract_patterns(assertions)
      return [] unless assertions

      patterns = []

      # Add contains patterns
      if assertions['contains']
        assertions['contains'].each do |text|
          patterns << Regexp.escape(text)
        end
      end

      # Add regex patterns
      if assertions['matches']
        patterns.concat(assertions['matches'])
      end

      patterns
    end

    def cleanup_removed_tests
      # Mark tests as disabled if they're no longer in YAML
      yaml_test_names = test_definitions.map { |t| t['name'] }

      prompt.prompt_tests.where.not(name: yaml_test_names).each do |test|
        test.update(enabled: false) if test.enabled?
      end
    end
  end
end
```

### Phase 3: Integration with FileSyncService (Week 2)

**Tasks:**
1. Update `FileSyncService` to sync tests
2. Add test sync to auto-sync workflow
3. Handle test suite syncing
4. Update CLI commands
5. Write integration tests

**Files to Modify:**
- `app/services/prompt_tracker/file_sync_service.rb`

**FileSyncService Update:**
```ruby
# app/services/prompt_tracker/file_sync_service.rb
module PromptTracker
  class FileSyncService
    def sync_file(path, force: false)
      # ... existing prompt sync code ...

      # NEW: Sync tests if present
      if prompt_file.tests.present?
        test_results = PromptTestSyncService.sync(prompt, prompt_file.tests)
        result[:tests] = test_results
      end

      # NEW: Sync test suites if present
      if prompt_file.test_suites.present?
        suite_results = sync_test_suites(prompt, prompt_file.test_suites)
        result[:test_suites] = suite_results
      end

      result
    end

    private

    def sync_test_suites(prompt, suite_definitions)
      results = { created: 0, updated: 0, errors: [] }

      suite_definitions.each do |suite_def|
        suite = PromptTestSuite.find_or_initialize_by(
          name: suite_def['name'],
          prompt: prompt
        )

        suite.assign_attributes(
          description: suite_def['description'],
          tags: suite_def['tags'] || [],
          enabled: suite_def.fetch('enabled', true)
        )

        if suite.save
          # Link tests to suite
          link_tests_to_suite(suite, suite_def['tests'])

          results[suite.previously_new_record? ? :created : :updated] += 1
        else
          results[:errors] << suite.errors.full_messages.join(', ')
        end
      end

      results
    end

    def link_tests_to_suite(suite, test_names)
      return unless test_names

      test_names.each do |test_name|
        test = suite.prompt.prompt_tests.find_by(name: test_name)
        test&.update(prompt_test_suite: suite)
      end
    end
  end
end
```

### Phase 4: CLI Commands (Week 2)

**Tasks:**
1. Create Rake tasks for test management
2. Add test running commands
3. Support CI/CD integration
4. Add reporting options
5. Write documentation

**Files to Create:**
- `lib/tasks/prompt_tracker/test.rake`

**Rake Tasks:**
```ruby
# lib/tasks/prompt_tracker/test.rake
namespace :prompt_tracker do
  namespace :test do
    desc "Sync tests from YAML files"
    task sync: :environment do
      puts "Syncing tests from YAML files..."

      service = PromptTracker::FileSyncService.new
      results = service.sync_all

      puts "\nTest Sync Results:"
      puts "  Tests created: #{results[:tests][:created]}"
      puts "  Tests updated: #{results[:tests][:updated]}"
      puts "  Tests skipped: #{results[:tests][:skipped]}"

      if results[:tests][:errors].any?
        puts "\nErrors:"
        results[:tests][:errors].each { |e| puts "  - #{e}" }
        exit 1
      end
    end

    desc "Run all tests for a prompt"
    task :run, [:prompt_name] => :environment do |t, args|
      prompt = PromptTracker::Prompt.find_by!(name: args[:prompt_name])
      tests = prompt.prompt_tests.enabled

      puts "Running #{tests.count} tests for #{prompt.name}..."

      passed = 0
      failed = 0

      tests.each do |test|
        print "  #{test.name}... "

        test_run = test.run!

        if test_run.passed?
          puts "✓ PASSED"
          passed += 1
        else
          puts "✗ FAILED"
          failed += 1
        end
      end

      puts "\nResults: #{passed} passed, #{failed} failed"
      exit 1 if failed > 0
    end

    desc "Run a specific test"
    task :run_one, [:test_name] => :environment do |t, args|
      test = PromptTracker::PromptTest.find_by!(name: args[:test_name])

      puts "Running test: #{test.name}"
      test_run = test.run!

      if test_run.passed?
        puts "✓ PASSED"
        exit 0
      else
        puts "✗ FAILED"
        puts "Error: #{test_run.error_message}" if test_run.error_message
        exit 1
      end
    end

    desc "Run a test suite"
    task :suite, [:suite_name] => :environment do |t, args|
      suite = PromptTracker::PromptTestSuite.find_by!(name: args[:suite_name])

      puts "Running test suite: #{suite.name}"
      runner = PromptTracker::PromptTestSuiteRunner.new(suite)
      suite_run = runner.run!

      puts "\nResults:"
      puts "  Total: #{suite_run.total_tests}"
      puts "  Passed: #{suite_run.passed_tests}"
      puts "  Failed: #{suite_run.failed_tests}"
      puts "  Skipped: #{suite_run.skipped_tests}"
      puts "  Duration: #{suite_run.total_duration_ms}ms"

      exit 1 if suite_run.failed_tests > 0
    end

    desc "Run all tests (for CI)"
    task ci: :environment do
      # Sync tests first
      Rake::Task['prompt_tracker:test:sync'].invoke

      # Run all enabled tests
      tests = PromptTracker::PromptTest.enabled

      puts "Running #{tests.count} tests..."

      results = tests.map { |test| test.run! }

      passed = results.count(&:passed?)
      failed = results.count { |r| r.status == 'failed' }
      errors = results.count { |r| r.status == 'error' }

      puts "\nCI Test Results:"
      puts "  Total: #{results.count}"
      puts "  Passed: #{passed}"
      puts "  Failed: #{failed}"
      puts "  Errors: #{errors}"

      exit 1 if (failed + errors) > 0
    end
  end
end
```

## 📝 Example YAML Files

### Simple Test Example
```yaml
# app/prompts/support/greeting.yml
name: customer_support_greeting
template: "Hi {{name}}!"
variables:
  - name: name
    type: string
    required: true

tests:
  - name: basic_greeting
    variables:
      name: "Alice"
    assertions:
      contains: ["Alice"]
```

### Complex Test Example
```yaml
# app/prompts/email/summary.yml
name: email_summary
template: |
  {% if urgent %}URGENT: {% endif %}
  Summary of email from {{sender}}:
  {{content | truncate: 200}}

variables:
  - name: sender
    type: string
  - name: content
    type: string
  - name: urgent
    type: boolean

tests:
  - name: urgent_email_summary
    description: Test urgent email gets flagged
    variables:
      sender: "CEO"
      content: "We need to discuss the quarterly results immediately."
      urgent: true

    assertions:
      contains:
        - "URGENT"
        - "CEO"
      matches:
        - "^URGENT:"

    evaluators:
      - evaluator: length_check
        config:
          max_length: 250
        threshold: 100

  - name: normal_email_summary
    description: Test normal email without urgent flag
    variables:
      sender: "Marketing Team"
      content: "Here's the latest newsletter draft for review."
      urgent: false

    assertions:
      not_contains:
        - "URGENT"
      contains:
        - "Marketing Team"
```

## 🧪 Testing Strategy

### Unit Tests
- `PromptFile` test parsing
- `PromptTestFile` validation
- `PromptTestSyncService` sync logic

### Integration Tests
- Full YAML to database sync
- Test execution from YAML
- Suite creation and execution

### System Tests
- CI workflow simulation
- Auto-sync on file change
- Test result reporting

## 📊 Success Metrics

- **Test Coverage** - % of prompts with YAML tests
- **Sync Success Rate** - % of successful syncs
- **CI Integration** - Number of projects using test CI
- **Developer Adoption** - Tests created via YAML vs UI
