# PromptTracker Testing Plan

## Current Test Coverage Analysis

### ✅ **Existing Tests (Minitest)**

#### Models (6/8 tested - 75%)
- ✅ `prompt_test.rb` - Prompt model
- ✅ `prompt_version_test.rb` - PromptVersion model
- ✅ `llm_response_test.rb` - LlmResponse model
- ✅ `evaluation_test.rb` - Evaluation model
- ✅ `ab_test_test.rb` - AbTest model
- ✅ `prompt_file_test.rb` - PromptFile model (PORO)
- ❌ **MISSING: `evaluator_config_test.rb`** - EvaluatorConfig model
- ❌ **MISSING: `application_record_test.rb`** - ApplicationRecord (likely not needed)

#### Services (7/11 tested - 64%)
- ✅ `file_sync_service_test.rb` - File sync service
- ✅ `llm_call_service_test.rb` - LLM API integration
- ✅ `cost_calculator_test.rb` - Cost calculation
- ✅ `evaluation_service_test.rb` - Evaluation orchestration
- ✅ `evaluation_helpers_test.rb` - Evaluation helper methods
- ✅ `response_extractor_test.rb` - Response extraction
- ✅ `evaluators/` - All 4 evaluators tested
  - ✅ `format_evaluator_test.rb`
  - ✅ `keyword_evaluator_test.rb`
  - ✅ `length_evaluator_test.rb`
  - ✅ `llm_judge_evaluator_test.rb`
- ❌ **MISSING: `ab_test_analyzer_test.rb`** - A/B test statistical analysis
- ❌ **MISSING: `ab_test_coordinator_test.rb`** - A/B test coordination
- ❌ **MISSING: `auto_evaluation_service_test.rb`** - Auto-evaluation on response creation
- ❌ **MISSING: `evaluator_registry_test.rb`** - Evaluator registry

#### Controllers (1/7 tested - 14%)
- ✅ `basic_authentication_test.rb` - Authentication concern
- ❌ **MISSING: `prompts_controller_test.rb`** - Prompts CRUD
- ❌ **MISSING: `prompt_versions_controller_test.rb`** - Versions CRUD
- ❌ **MISSING: `llm_responses_controller_test.rb`** - Responses CRUD
- ❌ **MISSING: `evaluations_controller_test.rb`** - Evaluations CRUD
- ❌ **MISSING: `evaluator_configs_controller_test.rb`** - Evaluator configs CRUD
- ❌ **MISSING: `ab_tests_controller_test.rb`** - A/B tests CRUD
- ❌ **MISSING: `analytics/dashboard_controller_test.rb`** - Analytics dashboard

#### Jobs (0/3 tested - 0%)
- ❌ **MISSING: `evaluation_job_test.rb`** - Background evaluation job
- ❌ **MISSING: `llm_judge_evaluation_job_test.rb`** - LLM judge background job
- ❌ **MISSING: `application_job_test.rb`** - Base job (likely not needed)

#### Integration Tests (0/? tested - 0%)
- ✅ `navigation_test.rb` exists but is empty
- ❌ **MISSING: Full user workflow tests**
- ❌ **MISSING: A/B testing workflow tests**
- ❌ **MISSING: Evaluation workflow tests**
- ❌ **MISSING: Auto-evaluation workflow tests**

#### System/Request Tests (0/? tested - 0%)
- ❌ **MISSING: End-to-end UI tests**
- ❌ **MISSING: API endpoint tests**

---

## 📋 **Missing Tests - Priority Order**

### **🔴 HIGH PRIORITY - Critical Business Logic**

#### 1. **Model: EvaluatorConfig** (`test/models/prompt_tracker/evaluator_config_test.rb`)
**Why:** Core model for auto-evaluation feature, no tests at all
**What to test:**
- Validations (presence, uniqueness, config structure)
- Associations (belongs_to prompt, has_many evaluations)
- Scopes (active, for_prompt, by_evaluator_type)
- Methods (active?, config validation)
- Callbacks (if any)

#### 2. **Service: AutoEvaluationService** (`test/services/prompt_tracker/auto_evaluation_service_test.rb`)
**Why:** Automatically evaluates responses on creation - critical feature
**What to test:**
- Triggering evaluation on response creation
- Running all configured evaluators for a prompt
- Handling evaluator failures gracefully
- Creating evaluation records correctly
- Performance with multiple evaluators
- Edge cases (no configs, disabled configs)

#### 3. **Service: AbTestCoordinator** (`test/services/prompt_tracker/ab_test_coordinator_test.rb`)
**Why:** Orchestrates A/B testing - core feature
**What to test:**
- Variant selection based on traffic split
- Recording responses with correct variant
- Handling concurrent requests
- Edge cases (no running test, invalid variant)
- Integration with LlmCallService

#### 4. **Service: AbTestAnalyzer** (`test/services/prompt_tracker/ab_test_analyzer_test.rb`)
**Why:** Statistical analysis for A/B tests - complex business logic
**What to test:**
- Statistical significance calculations
- Confidence interval calculations
- Winner determination logic
- Sample size validation
- Different metrics (cost, response_time, quality_score)
- Edge cases (insufficient data, tied results)

#### 5. **Service: EvaluatorRegistry** (`test/services/prompt_tracker/evaluator_registry_test.rb`)
**Why:** Central registry for all evaluators - critical infrastructure
**What to test:**
- Registering evaluators
- Retrieving evaluators by key
- Listing all evaluators
- Validating evaluator structure
- Handling duplicate registrations
- Thread safety (if applicable)

---

### **🟡 MEDIUM PRIORITY - User-Facing Features**

#### 6. **Controller: PromptsController** (`test/controllers/prompt_tracker/prompts_controller_test.rb`)
**What to test:**
- Index action (list all prompts)
- Show action (view single prompt)
- New/Create actions (create prompt)
- Edit/Update actions (update prompt)
- Destroy action (delete/archive prompt)
- Authorization/authentication
- Error handling
- JSON/HTML responses

#### 7. **Controller: PromptVersionsController** (`test/controllers/prompt_tracker/prompt_versions_controller_test.rb`)
**What to test:**
- Index action (list versions for a prompt)
- Show action (view single version)
- New/Create actions (create new version)
- Edit/Update actions (update version)
- Activate action (activate a version)
- Destroy action (delete version)
- Render action (preview rendered prompt)

#### 8. **Controller: LlmResponsesController** (`test/controllers/prompt_tracker/llm_responses_controller_test.rb`)
**What to test:**
- Index action (list responses)
- Show action (view single response with evaluations)
- Create action (record new response)
- Filtering/searching responses
- Pagination
- JSON responses for API usage

#### 9. **Controller: EvaluationsController** (`test/controllers/prompt_tracker/evaluations_controller_test.rb`)
**What to test:**
- Create action (manual evaluation)
- Form loading for different evaluator types
- Config parameter processing
- Background job triggering for LLM judge
- Error handling for invalid configs
- JSON responses

#### 10. **Controller: EvaluatorConfigsController** (`test/controllers/prompt_tracker/evaluator_configs_controller_test.rb`)
**What to test:**
- Index action (list configs for a prompt)
- Create action (add new config)
- Update action (modify config)
- Destroy action (remove config)
- Toggle active/inactive
- Config validation
- Form rendering for different evaluator types

#### 11. **Controller: AbTestsController** (`test/controllers/prompt_tracker/ab_tests_controller_test.rb`)
**What to test:**
- Index action (list A/B tests)
- Show action (view test with results)
- New/Create actions (create test)
- Edit/Update actions (modify test)
- Start/Pause/Resume/Complete/Cancel actions
- Results display
- Statistical analysis display

#### 12. **Controller: Analytics::DashboardController** (`test/controllers/prompt_tracker/analytics/dashboard_controller_test.rb`)
**What to test:**
- Index action (main dashboard)
- Data aggregation
- Chart data generation
- Filtering by date range
- Performance with large datasets

---

### **🟢 LOW PRIORITY - Background Jobs & Integration**

#### 13. **Job: EvaluationJob** (`test/jobs/prompt_tracker/evaluation_job_test.rb`)
**What to test:**
- Job enqueuing
- Job execution
- Calling EvaluationService correctly
- Error handling and retries
- Job arguments serialization

#### 14. **Job: LlmJudgeEvaluationJob** (`test/jobs/prompt_tracker/llm_judge_evaluation_job_test.rb`)
**What to test:**
- Job enqueuing
- Job execution
- Calling LlmJudgeEvaluator correctly
- Creating evaluation record
- Error handling and retries
- API failures

#### 15. **Integration: Evaluation Workflow** (`test/integration/evaluation_workflow_test.rb`)
**What to test:**
- Complete evaluation flow from UI
- Auto-evaluation on response creation
- Manual evaluation submission
- LLM judge evaluation flow
- Multiple evaluators on same response

#### 16. **Integration: A/B Testing Workflow** (`test/integration/ab_testing_workflow_test.rb`)
**What to test:**
- Creating and starting an A/B test
- Recording responses with variants
- Analyzing results
- Completing test with winner
- Promoting winner version

#### 17. **Integration: Prompt Management Workflow** (`test/integration/prompt_management_workflow_test.rb`)
**What to test:**
- Creating prompt from UI
- Creating versions
- Activating versions
- Syncing from files
- Archiving prompts

---

## 📊 **Test Coverage Summary**

### Current Coverage
```
Models:        6/8   = 75%  ✅ Good
Services:      7/11  = 64%  ⚠️  Needs work
Controllers:   1/7   = 14%  ❌ Critical gap
Jobs:          0/3   = 0%   ❌ Critical gap
Integration:   0/5   = 0%   ❌ Critical gap
-----------------------------------
TOTAL:        14/34  = 41%  ❌ Needs significant work
```

### Target Coverage After RSpec Implementation
```
Models:        8/8   = 100% ✅
Services:     11/11  = 100% ✅
Controllers:   7/7   = 100% ✅
Jobs:          3/3   = 100% ✅
Integration:   5/5   = 100% ✅
-----------------------------------
TOTAL:        34/34  = 100% ✅
```

---

## 🎯 **Recommended Testing Strategy**

### Phase 1: Critical Business Logic (Week 1)
1. EvaluatorConfig model
2. AutoEvaluationService
3. AbTestCoordinator
4. AbTestAnalyzer
5. EvaluatorRegistry

### Phase 2: Controllers (Week 2)
6. PromptsController
7. PromptVersionsController
8. LlmResponsesController
9. EvaluationsController
10. EvaluatorConfigsController
11. AbTestsController
12. Analytics::DashboardController

### Phase 3: Jobs & Integration (Week 3)
13. EvaluationJob
14. LlmJudgeEvaluationJob
15. Evaluation workflow integration tests
16. A/B testing workflow integration tests
17. Prompt management workflow integration tests

---

## 🛠️ **Testing Tools & Setup**

### RSpec Setup
- **rspec-rails** - Main testing framework
- **factory_bot_rails** - Test data factories
- **faker** - Realistic fake data
- **shoulda-matchers** - Model validation matchers
- **database_cleaner** - Clean test database
- **simplecov** - Code coverage reporting
- **webmock** - HTTP request stubbing (for LLM API calls)
- **vcr** - Record/replay HTTP interactions

### Test Types
1. **Model specs** - Validations, associations, scopes, methods
2. **Service specs** - Business logic, edge cases, error handling
3. **Controller specs** - HTTP requests, responses, authorization
4. **Job specs** - Background job execution, retries
5. **Request specs** - Full HTTP request/response cycle
6. **System specs** - Browser-based end-to-end tests (optional)

---

## 📝 **Next Steps**

1. ✅ **Install RSpec** - Add gems to Gemfile
2. ✅ **Initialize RSpec** - Run `rails generate rspec:install`
3. ⬜ **Create FactoryBot factories** - For all models
4. ⬜ **Set up test helpers** - Common test utilities
5. ⬜ **Start with Phase 1** - Critical business logic tests
6. ⬜ **Measure coverage** - Use SimpleCov to track progress
7. ⬜ **Iterate** - Continue through Phase 2 and 3

---

## 🎓 **Testing Best Practices**

1. **Follow AAA pattern** - Arrange, Act, Assert
2. **One assertion per test** - Keep tests focused
3. **Use descriptive test names** - Explain what's being tested
4. **Test edge cases** - Not just happy path
5. **Mock external dependencies** - LLM APIs, file system
6. **Keep tests fast** - Use factories, not fixtures
7. **Test behavior, not implementation** - Focus on outcomes
8. **Use shared examples** - For common behavior (evaluators)
9. **Test error conditions** - Failures, validations, exceptions
10. **Maintain test data** - Keep factories up to date
