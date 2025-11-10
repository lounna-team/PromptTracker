# A/B Testing Feature - Design Document

## Table of Contents
1. [Overview](#overview)
2. [Use Cases](#use-cases)
3. [Architecture](#architecture)
4. [Database Schema](#database-schema)
5. [Core Components](#core-components)
6. [User Workflow](#user-workflow)
7. [Statistical Analysis](#statistical-analysis)
8. [Implementation Plan](#implementation-plan)
9. [API Examples](#api-examples)
10. [Design Decisions](#design-decisions)

---

## Overview

### What is A/B Testing for Prompts?

A/B testing (also called split testing) allows you to compare two or more prompt versions in production to determine which performs better based on real-world metrics.

**The Problem:**
- You have two versions of a prompt (e.g., v1: formal tone, v2: casual tone)
- You want to know which one performs better in production
- You need statistical confidence before fully switching

**The Solution:**
- Run both versions simultaneously
- Split traffic between them (e.g., 50/50 or 80/20)
- Track performance metrics (response time, cost, quality scores)
- Analyze results with statistical significance
- Promote the winner

---

## Use Cases

### 1. **Prompt Optimization**
**Scenario:** You've created a shorter version of a prompt to reduce costs.

```yaml
# Version 1 (current)
template: |
  You are a helpful customer support agent. Please assist the customer
  with their question about {{topic}}. Be professional and thorough.

# Version 2 (optimized)
template: |
  Help customer with {{topic}}. Be professional.
```

**Goal:** Verify v2 maintains quality while reducing cost.

### 2. **Tone Experimentation**
**Scenario:** Testing formal vs. casual tone for customer support.

**Metrics to compare:**
- Customer satisfaction scores
- Response quality (via LLM judge)
- Conversation length

### 3. **Model Comparison**
**Scenario:** Testing GPT-4 vs Claude-3 for the same prompt.

**Metrics to compare:**
- Response time
- Cost per call
- Quality scores
- Error rates

### 4. **Variable Testing**
**Scenario:** Testing different system instructions or examples.

**Goal:** Find the optimal prompt structure.

---

## Architecture

### High-Level Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    APPLICATION REQUEST                       │
│  User triggers LLM call (e.g., customer asks question)      │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────┐
│                   A/B TEST COORDINATOR                       │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ 1. Check if prompt has active A/B test               │  │
│  │ 2. If yes → Select variant based on traffic split    │  │
│  │ 3. If no → Use active version (normal flow)          │  │
│  └──────────────────────────────────────────────────────┘  │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────┐
│                    VARIANT SELECTION                         │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Traffic Split: 50% A / 50% B                         │  │
│  │                                                       │  │
│  │ Random(0-100) < 50 ?                                 │  │
│  │   → Variant A (version 1)                            │  │
│  │   → Variant B (version 2)                            │  │
│  └──────────────────────────────────────────────────────┘  │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────┐
│                    LLM CALL TRACKING                         │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ LlmCallService.track(                                │  │
│  │   prompt_name: "greeting",                           │  │
│  │   version: selected_version,                         │  │
│  │   ab_test_id: test.id,                               │  │
│  │   ab_variant: "A" or "B"                             │  │
│  │ )                                                    │  │
│  └──────────────────────────────────────────────────────┘  │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────┐
│                    METRICS COLLECTION                        │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ For each variant, track:                             │  │
│  │ - Response count                                     │  │
│  │ - Average response time                              │  │
│  │ - Average cost                                       │  │
│  │ - Success rate                                       │  │
│  │ - Average quality score (from evaluations)           │  │
│  │ - Error rate                                         │  │
│  └──────────────────────────────────────────────────────┘  │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────┐
│                  STATISTICAL ANALYSIS                        │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Calculate:                                           │  │
│  │ - Mean difference between variants                   │  │
│  │ - Standard deviation                                 │  │
│  │ - T-test for significance                            │  │
│  │ - Confidence interval                                │  │
│  │ - Sample size requirements                           │  │
│  └──────────────────────────────────────────────────────┘  │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────┐
│                    DECISION & ACTION                         │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ If statistically significant winner found:           │  │
│  │   → Mark test as "completed"                         │  │
│  │   → Activate winning version                         │  │
│  │   → Deprecate losing version                         │  │
│  │                                                       │  │
│  │ If not significant yet:                              │  │
│  │   → Continue collecting data                         │  │
│  │   → Show progress in dashboard                       │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## Database Schema

### New Table: `prompt_tracker_ab_tests`

```ruby
create_table :prompt_tracker_ab_tests do |t|
  # Basic Info
  t.references :prompt, null: false, foreign_key: { to_table: :prompt_tracker_prompts }
  t.string :name, null: false
  t.text :description
  t.string :hypothesis  # "Version 2 will reduce cost by 30% while maintaining quality"

  # Test Configuration
  t.string :status, null: false, default: "draft"
  # Status: draft, running, paused, completed, cancelled

  t.string :metric_to_optimize, null: false
  # Options: "cost", "response_time", "quality_score", "success_rate", "custom"

  t.string :optimization_direction, null: false, default: "minimize"
  # Options: "minimize" (for cost/time), "maximize" (for quality/success)

  # Traffic Split
  t.jsonb :traffic_split, null: false, default: {}
  # Example: { "A" => 50, "B" => 50 } or { "A" => 80, "B" => 20 }

  # Variants
  t.jsonb :variants, null: false, default: []
  # Example: [
  #   { "name" => "A", "version_id" => 1, "description" => "Current version" },
  #   { "name" => "B", "version_id" => 2, "description" => "Optimized version" }
  # ]

  # Statistical Configuration
  t.float :confidence_level, default: 0.95  # 95% confidence
  t.float :minimum_detectable_effect, default: 0.05  # 5% improvement
  t.integer :minimum_sample_size, default: 100  # per variant

  # Results (cached for performance)
  t.jsonb :results, default: {}
  # Example: {
  #   "A" => { "count" => 500, "mean" => 1200, "std_dev" => 150 },
  #   "B" => { "count" => 500, "mean" => 950, "std_dev" => 140 },
  #   "winner" => "B",
  #   "p_value" => 0.001,
  #   "confidence" => 0.999,
  #   "improvement" => 20.8
  # }

  # Timing
  t.datetime :started_at
  t.datetime :completed_at
  t.datetime :cancelled_at

  # Metadata
  t.string :created_by
  t.jsonb :metadata, default: {}

  t.timestamps
end

add_index :prompt_tracker_ab_tests, :status
add_index :prompt_tracker_ab_tests, :metric_to_optimize
add_index :prompt_tracker_ab_tests, [:prompt_id, :status]
```

### Updates to Existing Tables

#### `prompt_tracker_llm_responses`
Add columns to track A/B test participation:

```ruby
add_column :prompt_tracker_llm_responses, :ab_test_id, :bigint
add_column :prompt_tracker_llm_responses, :ab_variant, :string

add_index :prompt_tracker_llm_responses, :ab_test_id
add_index :prompt_tracker_llm_responses, [:ab_test_id, :ab_variant]
add_foreign_key :prompt_tracker_llm_responses, :prompt_tracker_ab_tests, column: :ab_test_id
```

---

## Core Components

### 1. AbTest Model

```ruby
module PromptTracker
  class AbTest < ApplicationRecord
    # Associations
    belongs_to :prompt
    has_many :llm_responses, dependent: :nullify

    # Validations
    validates :name, presence: true
    validates :status, inclusion: { in: %w[draft running paused completed cancelled] }
    validates :metric_to_optimize, presence: true
    validates :optimization_direction, inclusion: { in: %w[minimize maximize] }
    validates :traffic_split, presence: true
    validates :variants, presence: true

    validate :traffic_split_sums_to_100
    validate :variants_have_valid_versions
    validate :only_one_running_test_per_prompt

    # Scopes
    scope :running, -> { where(status: "running") }
    scope :completed, -> { where(status: "completed") }
    scope :for_prompt, ->(prompt_id) { where(prompt_id: prompt_id) }

    # State machine
    def start!
      update!(status: "running", started_at: Time.current)
    end

    def pause!
      update!(status: "paused")
    end

    def complete!(winner:)
      update!(
        status: "completed",
        completed_at: Time.current,
        results: results.merge("winner" => winner)
      )
    end

    def cancel!
      update!(status: "cancelled", cancelled_at: Time.current)
    end

    # Variant selection
    def select_variant
      # Weighted random selection based on traffic_split
      random_value = rand(100)
      cumulative = 0

      traffic_split.each do |variant_name, percentage|
        cumulative += percentage
        return variant_name if random_value < cumulative
      end

      traffic_split.keys.first # Fallback
    end

    def version_for_variant(variant_name)
      variant = variants.find { |v| v["name"] == variant_name }
      prompt.prompt_versions.find(variant["version_id"])
    end
  end
end
```

### 2. AbTestCoordinator Service

```ruby
module PromptTracker
  class AbTestCoordinator
    def self.select_version_for_prompt(prompt_name)
      prompt = Prompt.find_by(name: prompt_name)
      return nil unless prompt

      # Check for running A/B test
      ab_test = prompt.ab_tests.running.first
      return { version: prompt.active_version, ab_test: nil } unless ab_test

      # Select variant
      variant_name = ab_test.select_variant
      version = ab_test.version_for_variant(variant_name)

      {
        version: version,
        ab_test: ab_test,
        variant: variant_name
      }
    end
  end
end
```

### 3. Updated LlmCallService

```ruby
# Modify existing LlmCallService.track method
def self.track(prompt_name:, variables: {}, provider:, model:, version: nil, **options, &block)
  # If version is explicitly specified, use it (no A/B testing)
  if version
    return track_with_version(prompt_name, version, variables, provider, model, options, &block)
  end

  # Check for A/B test
  selection = AbTestCoordinator.select_version_for_prompt(prompt_name)

  # Track with A/B test metadata
  track_with_version(
    prompt_name,
    selection[:version].version_number,
    variables,
    provider,
    model,
    options.merge(
      ab_test_id: selection[:ab_test]&.id,
      ab_variant: selection[:variant]
    ),
    &block
  )
end
```

### 4. AbTestAnalyzer Service

```ruby
module PromptTracker
  class AbTestAnalyzer
    def initialize(ab_test)
      @ab_test = ab_test
    end

    def analyze
      variants_data = collect_variant_data
      statistical_results = calculate_statistics(variants_data)
      winner = determine_winner(statistical_results)

      {
        variants: variants_data,
        statistics: statistical_results,
        winner: winner,
        is_significant: statistical_results[:p_value] < (1 - @ab_test.confidence_level),
        recommendation: generate_recommendation(winner, statistical_results)
      }
    end

    private

    def collect_variant_data
      metric = @ab_test.metric_to_optimize

      @ab_test.variants.map do |variant|
        responses = @ab_test.llm_responses.where(ab_variant: variant["name"])

        {
          name: variant["name"],
          count: responses.count,
          mean: calculate_mean(responses, metric),
          std_dev: calculate_std_dev(responses, metric),
          median: calculate_median(responses, metric),
          min: responses.minimum(metric_column(metric)),
          max: responses.maximum(metric_column(metric))
        }
      end
    end

    def calculate_statistics(variants_data)
      # Perform t-test between variants
      # Calculate p-value, confidence interval, effect size
      # Return statistical significance
    end

    def determine_winner(statistical_results)
      # Based on optimization direction and statistical significance
    end
  end
end
```

---

## User Workflow

### Creating an A/B Test

#### Step 1: Prepare Variants
First, ensure you have multiple versions of your prompt:

```bash
# Version 1 already exists (current production)
# Create version 2 via YAML file

# app/prompts/customer_greeting.yml
name: customer_greeting
description: Greeting for customer support
template: |
  Hi {{customer_name}}! How can I help with {{issue}}?
```

```bash
# Sync to create version 2
rails prompt_tracker:sync
```

#### Step 2: Create A/B Test via Web UI

Navigate to: `/prompt_tracker/prompts/:id/ab_tests/new`

**Form Fields:**
- **Test Name:** "Shorter greeting test"
- **Hypothesis:** "Version 2 will reduce response time by 20% while maintaining quality"
- **Metric to Optimize:** Response Time
- **Optimization Direction:** Minimize
- **Confidence Level:** 95%
- **Minimum Sample Size:** 200 per variant

**Variants Configuration:**
- Variant A: Version 1 (50% traffic)
- Variant B: Version 2 (50% traffic)

#### Step 3: Start the Test

```ruby
# Via console or UI button
ab_test = AbTest.find(1)
ab_test.start!
```

#### Step 4: Monitor Progress

Dashboard shows:
- Current sample sizes (A: 150, B: 145)
- Current metrics (A: 1200ms avg, B: 950ms avg)
- Statistical significance (p-value: 0.12, not significant yet)
- Progress bar (295/400 total samples needed)

#### Step 5: Analyze Results

Once minimum sample size is reached:

```ruby
analyzer = AbTestAnalyzer.new(ab_test)
results = analyzer.analyze

# Results:
# {
#   winner: "B",
#   is_significant: true,
#   p_value: 0.001,
#   improvement: 20.8%,
#   recommendation: "Promote variant B to production"
# }
```

#### Step 6: Promote Winner

```ruby
ab_test.complete!(winner: "B")
ab_test.promote_winner!  # Activates version 2, deprecates version 1
```

---

## Statistical Analysis

### Metrics We Track

#### 1. **Response Time** (minimize)
- Mean response time per variant
- Standard deviation
- P95, P99 percentiles

#### 2. **Cost** (minimize)
- Average cost per call
- Total cost per variant
- Cost per successful response

#### 3. **Quality Score** (maximize)
- Average evaluation score
- Score distribution
- Percentage of high-quality responses (score > 4.0)

#### 4. **Success Rate** (maximize)
- Percentage of successful responses
- Error rate
- Timeout rate

### Statistical Tests

#### T-Test for Continuous Metrics
For metrics like response time, cost, quality score:

```ruby
def perform_t_test(variant_a_data, variant_b_data)
  mean_a = variant_a_data.mean
  mean_b = variant_b_data.mean

  std_a = variant_a_data.std_dev
  std_b = variant_b_data.std_dev

  n_a = variant_a_data.count
  n_b = variant_b_data.count

  # Calculate t-statistic
  pooled_std = Math.sqrt(((n_a - 1) * std_a**2 + (n_b - 1) * std_b**2) / (n_a + n_b - 2))
  t_stat = (mean_a - mean_b) / (pooled_std * Math.sqrt(1.0/n_a + 1.0/n_b))

  # Calculate degrees of freedom
  df = n_a + n_b - 2

  # Calculate p-value (using t-distribution)
  p_value = calculate_p_value(t_stat, df)

  {
    t_statistic: t_stat,
    p_value: p_value,
    degrees_of_freedom: df,
    mean_difference: mean_b - mean_a,
    percent_change: ((mean_b - mean_a) / mean_a * 100).round(2)
  }
end
```

#### Chi-Square Test for Categorical Metrics
For metrics like success rate:

```ruby
def perform_chi_square_test(variant_a_successes, variant_a_total,
                            variant_b_successes, variant_b_total)
  # 2x2 contingency table
  # Calculate chi-square statistic and p-value
end
```

### Sample Size Calculation

```ruby
def calculate_required_sample_size(baseline_mean:, minimum_detectable_effect:,
                                   std_dev:, confidence_level: 0.95, power: 0.8)
  # Using power analysis
  # Returns minimum sample size per variant

  z_alpha = 1.96  # for 95% confidence
  z_beta = 0.84   # for 80% power

  effect_size = minimum_detectable_effect * baseline_mean

  n = 2 * ((z_alpha + z_beta) * std_dev / effect_size)**2
  n.ceil
end
```

### Early Stopping Criteria

To avoid running tests longer than necessary:

```ruby
def should_stop_early?(ab_test)
  results = AbTestAnalyzer.new(ab_test).analyze

  # Stop if:
  # 1. Statistically significant winner found
  return true if results[:is_significant] && results[:winner]

  # 2. Futility - unlikely to reach significance
  return true if futility_analysis(results) == :stop

  # 3. Maximum duration reached (e.g., 30 days)
  return true if ab_test.started_at < 30.days.ago

  false
end
```

---

## Implementation Plan

### Phase 1: Database & Models (Week 1)

**Tasks:**
1. Create migration for `prompt_tracker_ab_tests` table
2. Add `ab_test_id` and `ab_variant` to `llm_responses` table
3. Create `AbTest` model with validations
4. Write model tests

**Files to Create:**
- `db/migrate/XXXXXX_create_prompt_tracker_ab_tests.rb`
- `db/migrate/XXXXXX_add_ab_test_to_llm_responses.rb`
- `app/models/prompt_tracker/ab_test.rb`
- `test/models/prompt_tracker/ab_test_test.rb`

**Acceptance Criteria:**
- ✅ Can create A/B test with variants
- ✅ Validations prevent invalid configurations
- ✅ Only one running test per prompt
- ✅ Traffic split sums to 100%

---

### Phase 2: Core Services (Week 2)

**Tasks:**
1. Create `AbTestCoordinator` service
2. Update `LlmCallService` to support A/B testing
3. Create `AbTestAnalyzer` service for statistical analysis
4. Write service tests

**Files to Create:**
- `app/services/prompt_tracker/ab_test_coordinator.rb`
- `app/services/prompt_tracker/ab_test_analyzer.rb`
- `test/services/prompt_tracker/ab_test_coordinator_test.rb`
- `test/services/prompt_tracker/ab_test_analyzer_test.rb`

**Files to Modify:**
- `app/services/prompt_tracker/llm_call_service.rb`

**Acceptance Criteria:**
- ✅ Variant selection works with traffic split
- ✅ LLM responses tagged with A/B test metadata
- ✅ Statistical analysis calculates correctly
- ✅ Winner determination is accurate

---

### Phase 3: Web UI (Week 3)

**Tasks:**
1. Create A/B test controller
2. Create views for creating/managing tests
3. Create dashboard for monitoring tests
4. Add charts for visualizing results

**Files to Create:**
- `app/controllers/prompt_tracker/ab_tests_controller.rb`
- `app/views/prompt_tracker/ab_tests/index.html.erb`
- `app/views/prompt_tracker/ab_tests/new.html.erb`
- `app/views/prompt_tracker/ab_tests/show.html.erb`
- `app/views/prompt_tracker/ab_tests/_form.html.erb`
- `test/controllers/prompt_tracker/ab_tests_controller_test.rb`

**Routes to Add:**
```ruby
resources :prompts do
  resources :ab_tests do
    member do
      post :start
      post :pause
      post :complete
      post :cancel
      get :results
    end
  end
end

namespace :analytics do
  resources :ab_tests, only: [:index, :show]
end
```

**Acceptance Criteria:**
- ✅ Can create A/B test via web UI
- ✅ Can start/pause/stop tests
- ✅ Dashboard shows real-time progress
- ✅ Results page shows statistical analysis
- ✅ Can promote winner with one click

---

### Phase 4: Analytics & Reporting (Week 4)

**Tasks:**
1. Create analytics dashboard for A/B tests
2. Add charts comparing variants
3. Create export functionality (CSV, PDF)
4. Add email notifications for significant results

**Files to Create:**
- `app/controllers/prompt_tracker/analytics/ab_tests_controller.rb`
- `app/views/prompt_tracker/analytics/ab_tests/index.html.erb`
- `app/views/prompt_tracker/analytics/ab_tests/show.html.erb`
- `app/services/prompt_tracker/ab_test_reporter.rb`
- `app/mailers/prompt_tracker/ab_test_mailer.rb`

**Acceptance Criteria:**
- ✅ Dashboard shows all running tests
- ✅ Charts compare variants visually
- ✅ Can export results to CSV
- ✅ Email sent when test reaches significance

---

### Phase 5: Advanced Features (Week 5)

**Tasks:**
1. Multi-variant testing (A/B/C/D)
2. Sequential testing (automatic winner promotion)
3. Segment-based testing (different splits for different user groups)
4. Bayesian analysis (alternative to frequentist)

**Optional Enhancements:**
- Automatic rollback if winner performs worse
- Gradual rollout (increase winner traffic over time)
- Cost-based early stopping (stop if cost difference is significant)


---

## API Examples

### Creating an A/B Test Programmatically

```ruby
# Create test
ab_test = PromptTracker::AbTest.create!(
  prompt: prompt,
  name: "Shorter greeting test",
  description: "Testing if shorter greeting maintains quality",
  hypothesis: "Version 2 will reduce response time by 20%",
  metric_to_optimize: "response_time",
  optimization_direction: "minimize",
  traffic_split: { "A" => 50, "B" => 50 },
  variants: [
    { name: "A", version_id: 1, description: "Current version" },
    { name: "B", version_id: 2, description: "Shorter version" }
  ],
  confidence_level: 0.95,
  minimum_sample_size: 200
)

# Start test
ab_test.start!

# Check progress
ab_test.reload
ab_test.llm_responses.where(ab_variant: "A").count  # => 150
ab_test.llm_responses.where(ab_variant: "B").count  # => 145

# Analyze results
analyzer = PromptTracker::AbTestAnalyzer.new(ab_test)
results = analyzer.analyze

# If significant, promote winner
if results[:is_significant]
  ab_test.complete!(winner: results[:winner])
  ab_test.promote_winner!
end
```

### Using A/B Test in Application Code

```ruby
# Your application code doesn't change!
# A/B testing is transparent

class CustomerSupportController < ApplicationController
  include PromptTracker::Trackable

  def generate_greeting
    # This automatically participates in A/B test if one is running
    result = track_llm_call(
      "customer_greeting",
      variables: { customer_name: params[:name], issue: params[:issue] },
      provider: "openai",
      model: "gpt-4",
      user_id: current_user.id
    ) do |prompt|
      OpenAI::Client.new.chat(
        messages: [{ role: "user", content: prompt }]
      )
    end

    render json: { greeting: result[:response_text] }
  end
end
```

### Querying A/B Test Results

```ruby
# Get all running tests
running_tests = PromptTracker::AbTest.running

# Get test results
test = PromptTracker::AbTest.find(1)
analyzer = PromptTracker::AbTestAnalyzer.new(test)
results = analyzer.analyze

# Results structure:
{
  variants: {
    "A" => {
      count: 500,
      mean: 1200.5,
      std_dev: 150.2,
      median: 1180,
      min: 800,
      max: 2500
    },
    "B" => {
      count: 495,
      mean: 950.3,
      std_dev: 140.8,
      median: 920,
      min: 700,
      max: 2100
    }
  },
  statistics: {
    t_statistic: 12.45,
    p_value: 0.0001,
    degrees_of_freedom: 993,
    mean_difference: -250.2,
    percent_change: -20.8,
    confidence_interval: [-280.5, -219.9]
  },
  winner: "B",
  is_significant: true,
  recommendation: "Variant B shows 20.8% improvement with 99.99% confidence. Recommend promoting to production."
}
```


---

## Design Decisions

### 1. **Why Transparent A/B Testing?**

**Decision:** Application code doesn't need to know about A/B tests.

**Rationale:**
- Reduces code complexity
- No need to modify existing tracking calls
- Easy to start/stop tests without code changes
- Centralized control in PromptTracker

**Alternative Considered:** Explicit A/B test API
```ruby
# Rejected approach
ab_test.track_variant("A") { ... }
```
**Why Rejected:** Too invasive, requires code changes

---

### 2. **Why Store Results in JSONB?**

**Decision:** Cache statistical results in `results` JSONB column.

**Rationale:**
- Expensive to recalculate on every page load
- Results are immutable once test completes
- Flexible schema for different metrics

**Alternative Considered:** Separate `ab_test_results` table
**Why Rejected:** Overkill for simple key-value storage

---

### 3. **Why Limit to One Running Test Per Prompt?**

**Decision:** Only one A/B test can run per prompt at a time.

**Rationale:**
- Simplifies variant selection logic
- Avoids confounding variables
- Easier to interpret results
- Most common use case

**Alternative Considered:** Multiple concurrent tests
**Why Rejected:** Complex interaction effects, hard to analyze

---

### 4. **Why Use Frequentist Statistics (T-Test)?**

**Decision:** Use classical t-test for significance testing.

**Rationale:**
- Well-understood by most users
- Clear significance threshold (p < 0.05)
- Standard in industry
- Easy to implement

**Alternative Considered:** Bayesian analysis
**Why Considered:** Better for continuous monitoring, no p-hacking
**Status:** Could add as Phase 5 enhancement

---

### 5. **Why Traffic Split Instead of User-Based Split?**

**Decision:** Random traffic split on each request.

**Rationale:**
- Simpler implementation
- No need to track user assignments
- Works for anonymous users
- Faster variant selection

**Alternative Considered:** Consistent user assignment (same user always gets same variant)
**Why Rejected:** Requires user tracking, more complex
**Note:** Could add as optional feature later

---

### 6. **Why JSONB for Variants and Traffic Split?**

**Decision:** Store variants and traffic_split as JSONB instead of separate tables.

**Rationale:**
- Simpler schema (fewer joins)
- Variants are immutable once test starts
- Easy to query and update
- Flexible for future enhancements (e.g., metadata per variant)

**Alternative Considered:** Separate `ab_test_variants` table
**Why Rejected:** Adds complexity without clear benefit for typical use cases

---

### 7. **Why Cache Metrics in `results` Column?**

**Decision:** Periodically calculate and cache metrics instead of real-time calculation.

**Rationale:**
- Statistical calculations are expensive (especially with large datasets)
- Results don't need to be real-time (every few minutes is fine)
- Reduces database load
- Can use background job for calculation

**Implementation:**
```ruby
# Background job runs every 5 minutes
class UpdateAbTestResultsJob < ApplicationJob
  def perform
    AbTest.running.find_each do |test|
      analyzer = AbTestAnalyzer.new(test)
      test.update!(results: analyzer.analyze)
    end
  end
end
```

---

## Success Metrics

### For the A/B Testing Feature Itself

1. **Adoption:** Number of A/B tests created per month
2. **Completion Rate:** % of tests that reach statistical significance
3. **Time to Decision:** Average days from start to completion
4. **Impact:** Average improvement in optimized metric
5. **User Satisfaction:** Feedback from developers using the feature

### Example Success Story

```
Test: "Shorter customer greeting"
Duration: 7 days
Sample Size: 1,000 per variant
Result: Variant B (shorter) won
  - 22% faster response time (1200ms → 930ms)
  - 18% lower cost ($0.002 → $0.00164)
  - 2% higher quality score (4.2 → 4.28)
  - 99.9% confidence (p < 0.001)

Action: Promoted variant B to production
Impact: Saving $720/month on this prompt alone
```

---

## Next Steps

1. **Review this design document** with the team
2. **Gather feedback** on statistical approach
3. **Prioritize features** (MVP vs. nice-to-have)
4. **Start Phase 1** (Database & Models)
5. **Iterate based on real-world usage**

---

## Appendix: Statistical Formulas

### T-Test Formula

```
t = (mean_A - mean_B) / (s_pooled * sqrt(1/n_A + 1/n_B))

where:
  s_pooled = sqrt(((n_A - 1) * s_A^2 + (n_B - 1) * s_B^2) / (n_A + n_B - 2))
  df = n_A + n_B - 2
```

### Sample Size Formula (Power Analysis)

```
n = 2 * ((z_α + z_β) * σ / δ)^2

where:
  z_α = 1.96 (for 95% confidence)
  z_β = 0.84 (for 80% power)
  σ = standard deviation
  δ = minimum detectable effect
```

### Confidence Interval

```
CI = (mean_A - mean_B) ± (t_critical * SE)

where:
  SE = s_pooled * sqrt(1/n_A + 1/n_B)
  t_critical = t-value for desired confidence level and df
```

---

**This A/B testing feature will enable data-driven prompt optimization at scale!** 🚀
