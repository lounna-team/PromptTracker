# Testing Guide for PromptTracker

## Overview

PromptTracker uses **two test frameworks** to ensure comprehensive coverage:

- **Minitest** - Original test suite (14 files, ~412 tests)
- **RSpec** - Comprehensive test suite (19 files, ~271 tests)
  - Business Logic: ~100 tests (Models, Services, Registry)
  - Controllers: 144 tests (All 7 controllers)
  - Jobs: 27 tests (Both background jobs)

**Total Coverage:** ~683 tests across critical functionality

**Code Coverage:** 89.64% line coverage, 69.64% branch coverage (via SimpleCov)

---

## 🚀 Quick Start

### Run All Tests (Recommended)

```bash
# Option 1: Using the custom script (with colored output)
./bin/test_all

# Option 2: Using Rake task
bundle exec rake test_all

# Option 3: Using the default rake task
bundle exec rake
```

### Run Individual Test Suites

```bash
# Run only Minitest
bundle exec rails test

# Run only RSpec
bundle exec rspec
```

---

## 📁 Test Structure

### Minitest Tests (`test/` directory)

```
test/
├── models/prompt_tracker/          # Model tests (6 files)
│   ├── prompt_test.rb
│   ├── prompt_version_test.rb
│   ├── llm_response_test.rb
│   ├── evaluation_test.rb
│   ├── ab_test_test.rb
│   └── prompt_file_test.rb
├── services/prompt_tracker/        # Service tests (11 files)
│   ├── file_sync_service_test.rb
│   ├── llm_call_service_test.rb
│   ├── cost_calculator_test.rb
│   ├── evaluation_service_test.rb
│   ├── evaluation_helpers_test.rb
│   ├── response_extractor_test.rb
│   └── evaluators/                 # Evaluator tests (4 files)
│       ├── format_evaluator_test.rb
│       ├── keyword_evaluator_test.rb
│       ├── length_evaluator_test.rb
│       └── llm_judge_evaluator_test.rb
└── controllers/prompt_tracker/     # Controller tests (1 file)
    └── basic_authentication_test.rb
```

### RSpec Tests (`spec/` directory)

```
spec/
├── models/prompt_tracker/
│   └── evaluator_config_spec.rb           # 36 examples
├── services/prompt_tracker/
│   ├── ab_test_analyzer_spec.rb           # 14 examples
│   ├── ab_test_coordinator_spec.rb        # 19 examples
│   ├── auto_evaluation_service_spec.rb    # 10 examples
│   └── evaluator_registry_spec.rb         # 21 examples
├── factories/prompt_tracker/              # FactoryBot factories
│   ├── prompts.rb
│   ├── prompt_versions.rb
│   ├── llm_responses.rb
│   ├── evaluations.rb
│   ├── ab_tests.rb
│   └── evaluator_configs.rb
└── support/                               # Test configuration
    ├── database_cleaner.rb
    ├── factory_bot.rb
    └── shoulda_matchers.rb
```

---

## 🎯 What Each Suite Tests

### Minitest Coverage
- ✅ **Models:** Basic CRUD, validations, associations
- ✅ **Services:** File sync, LLM calls, cost calculation, evaluators
- ✅ **Controllers:** Authentication
- ✅ **Integration:** Basic navigation

### RSpec Coverage (Comprehensive Business Logic)

#### Models & Services (~100 tests)
- ✅ **EvaluatorConfig:** Dependencies, circular detection, priority, validation
- ✅ **AutoEvaluationService:** Auto-evaluation on response creation, sync/async modes
- ✅ **AbTestCoordinator:** Variant selection, traffic splitting, randomization
- ✅ **AbTestAnalyzer:** Statistical analysis, winner determination, confidence intervals
- ✅ **EvaluatorRegistry:** Registration, lookup, building, metadata

#### Controllers (144 tests)
- ✅ **PromptsController:** CRUD operations, pagination, search
- ✅ **PromptVersionsController:** Version management, activation, responses
- ✅ **EvaluatorConfigsController:** Config CRUD, validation, dependencies
- ✅ **AbTestsController:** A/B test lifecycle, pause/resume, winner declaration
- ✅ **LlmResponsesController:** Response listing, filtering, pagination
- ✅ **EvaluationsController:** Evaluation CRUD, manual evaluations, sorting
- ✅ **Analytics::DashboardController:** Dashboard data, charts, recent activity

#### Background Jobs (27 tests)
- ✅ **EvaluationJob:** Async evaluation execution, dependency checking, error handling
- ✅ **LlmJudgeEvaluationJob:** Manual LLM judge evaluations, retry logic, metadata storage

---

## 🔧 Running Specific Tests

### Minitest - Run Specific Files

```bash
# Run a specific test file
bundle exec rails test test/models/prompt_tracker/prompt_test.rb

# Run a specific test method
bundle exec rails test test/models/prompt_tracker/prompt_test.rb:10

# Run all model tests
bundle exec rails test test/models/**/*_test.rb

# Run all service tests
bundle exec rails test test/services/**/*_test.rb
```

### RSpec - Run Specific Files

```bash
# Run a specific spec file
bundle exec rspec spec/models/prompt_tracker/evaluator_config_spec.rb

# Run a specific example
bundle exec rspec spec/models/prompt_tracker/evaluator_config_spec.rb:25

# Run with documentation format
bundle exec rspec --format documentation

# Run with progress format (default)
bundle exec rspec --format progress
```

---

## 📊 Test Output

### Successful Run
```
✅ All tests passed!
Minitest: ✅ PASSED (412 examples)
RSpec:    ✅ PASSED (100 examples)
```

### Failed Run
```
❌ Some tests failed!
Minitest: ✅ PASSED (412 examples)
RSpec:    ❌ FAILED (95/100 passed, 5 failures)
```

---

## 🛠️ Continuous Integration

Add to your CI pipeline (e.g., GitHub Actions):

```yaml
- name: Run all tests
  run: bundle exec rake test_all
```

Or use the script:

```yaml
- name: Run all tests
  run: ./bin/test_all
```

---

## 📝 Writing New Tests

### For Minitest
```ruby
# test/models/prompt_tracker/my_model_test.rb
require "test_helper"

module PromptTracker
  class MyModelTest < ActiveSupport::TestCase
    test "should do something" do
      # Your test here
    end
  end
end
```

### For RSpec
```ruby
# spec/models/prompt_tracker/my_model_spec.rb
require "rails_helper"

RSpec.describe PromptTracker::MyModel do
  describe "#method_name" do
    it "does something" do
      # Your test here
    end
  end
end
```

---

## 📊 Test Coverage Reports

PromptTracker uses **SimpleCov** to track test coverage across both Minitest and RSpec.

### View Coverage Report

After running tests, open the HTML coverage report:

```bash
# Run all tests (generates coverage report)
bin/test_all

# Open coverage report in browser
open coverage/index.html
```

### Coverage Metrics

- **Line Coverage:** 89.64% (1842 / 2055 lines)
- **Branch Coverage:** 69.64% (539 / 774 branches)
- **Minimum Threshold:** 85% line coverage, 70% per-file coverage

### Coverage by Category

The report groups files by category:
- **Models** - Domain models and business logic
- **Controllers** - HTTP request handling
- **Services** - Business logic services
- **Jobs** - Background job processing
- **Helpers** - View helpers
- **Evaluators** - Evaluation implementations

### Understanding Coverage

- **Green files** (>90%) - Excellent coverage
- **Yellow files** (70-90%) - Good coverage
- **Red files** (<70%) - Needs more tests

**Note:** 100% coverage is not the goal. Focus on testing critical business logic and edge cases.

---

## 🎓 Best Practices

1. **Always run both suites** before committing
2. **Use factories** (FactoryBot) for test data in RSpec
3. **Use fixtures** for test data in Minitest
4. **Keep tests isolated** - each test should be independent
5. **Test edge cases** - not just happy paths
6. **Use descriptive test names** - explain what you're testing
7. **Disable auto-evaluation in tests** - Use `:disabled` trait on evaluator configs to prevent `after_create` callbacks from interfering

---

## 🐛 Troubleshooting

### Database Issues
```bash
# Reset test database
RAILS_ENV=test bundle exec rails db:reset
```

### Factory Issues
```bash
# Check factory definitions
bundle exec rails console
FactoryBot.factories.map(&:name)
```

### Clear Test Logs
```bash
rm -f test/dummy/log/test.log
```

---

## 📈 Coverage Goals

- **Current:** ~512 tests
- **Models:** 87.5% (7/8 tested)
- **Services:** 100% (11/11 tested)
- **Controllers:** 14% (1/7 tested) - Needs improvement
- **Jobs:** 0% (0/3 tested) - Needs improvement

---

For more details, see `TESTING_PLAN.md`
