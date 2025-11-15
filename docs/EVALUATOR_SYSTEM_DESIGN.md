# Evaluator System Architecture & UI/UX Design

**Status:** Planning Document
**Created:** 2025-11-12
**Purpose:** Comprehensive design for the evaluator registry, type-specific forms, and automatic evaluation system

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Problem Statement](#problem-statement)
3. [Architecture Overview](#architecture-overview)
4. [Core Components](#core-components)
5. [Multi-Evaluator Pattern & Score Aggregation](#multi-evaluator-pattern--score-aggregation)
   - [Core Principle: Multiple Evaluations per Response](#core-principle-multiple-evaluations-per-response)
   - [Score Aggregation Strategies](#score-aggregation-strategies)
6. [UI/UX Design](#uiux-design)
   - [Evaluation Breakdown Scorecard](#5-evaluation-breakdown-scorecard-multi-evaluator-display)
   - [Evaluation Status Indicator](#6-evaluation-status-indicator-for-async-evaluations)
   - [Prompt-Level Evaluator Configuration with Weights](#7-prompt-level-evaluator-configuration-with-weights)
7. [User Workflows](#user-workflows)
8. [Technical Implementation](#technical-implementation)
   - [Evaluation Dependencies & Conditional Execution](#evaluation-dependencies--conditional-execution)
9. [Database Schema](#database-schema)
10. [API Design](#api-design)
11. [Migration Strategy](#migration-strategy)
12. [Success Metrics](#success-metrics)
13. [Complete Example: Multi-Evaluator Setup](#complete-example-multi-evaluator-setup)
14. [Conclusion](#conclusion)

---

## Executive Summary

### Current State
- ✅ Evaluator classes exist (`LengthEvaluator`, `FormatEvaluator`, `KeywordEvaluator`, `LlmJudgeEvaluator`)
- ✅ Programmatic evaluation works via code
- ❌ **Single generic form** for all evaluator types (broken UX)
- ❌ **No UI to trigger** automated/LLM judge evaluations
- ❌ **No automatic evaluation** system
- ❌ **No evaluator discovery/registry**

### Proposed Solution
Build a comprehensive evaluator system with:
1. **Evaluator Registry** - Discover and manage evaluators
2. **Type-Specific Forms** - Different UI for human/automated/LLM judge
3. **Automatic Evaluation** - Trigger evaluations on response creation
4. **Prompt-Level Configuration** - Configure default evaluators per prompt
5. **Background Processing** - Async evaluation for LLM judges
6. **Developer Extensibility** - Easy to add custom evaluators

### Key Benefits
- ✅ **Better UX** - Appropriate forms for each evaluator type
- ✅ **Automation** - Evaluations run automatically
- ✅ **Extensibility** - Developers can add custom evaluators
- ✅ **Visibility** - See all available evaluators in UI
- ✅ **Configuration** - Set up evaluation rules per prompt

---

## Problem Statement

### The Current Form Problem

The existing evaluation form treats all evaluator types the same:

```erb
<!-- Current: ONE FORM FOR ALL TYPES -->
<select name="evaluator_type">
  <option value="human">Human</option>
  <option value="automated">Automated</option>
  <option value="llm_judge">LLM Judge</option>
</select>

<!-- Same fields for everyone -->
<input name="score" type="number">        <!-- ❌ Automated/LLM should compute this -->
<input name="evaluator_id" type="text">   <!-- ❌ Should be dropdown for automated -->
<textarea name="feedback"></textarea>     <!-- ❌ Automated/LLM should generate this -->
```

### Why This Doesn't Work

| Type | What User Provides | What Should Happen |
|------|-------------------|-------------------|
| **Human** | Score, Email, Feedback | ✅ Save directly to DB |
| **Automated** | ~~Score~~, ~~Evaluator ID~~ | ❌ Should select evaluator, configure it, **run it** |
| **LLM Judge** | ~~Score~~, ~~Judge Model~~ | ❌ Should configure criteria, **call LLM**, parse response |

### Missing Capabilities

1. **No Evaluator Discovery** - Can't see what evaluators are available
2. **No Configuration UI** - Can't configure evaluator parameters
3. **No Execution** - Forms don't actually run the evaluators
4. **No Automation** - Can't set "always run LengthEvaluator on this prompt"
5. **No Background Jobs** - LLM judge evaluations block the request

---

## Architecture Overview

### System Layers

```
┌─────────────────────────────────────────────────────────────┐
│ LAYER 1: UI/UX                                              │
│ - Type-specific forms (human/automated/llm_judge)           │
│ - Evaluator selection & configuration                       │
│ - Prompt-level evaluation settings                          │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ LAYER 2: Controllers & Services                             │
│ - EvaluationsController (type-aware routing)                │
│ - EvaluatorOrchestrator (runs evaluators)                   │
│ - AutoEvaluationService (automatic triggers)                │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ LAYER 3: Evaluator Registry                                 │
│ - EvaluatorRegistry (discover & manage evaluators)          │
│ - Evaluator metadata (name, description, config schema)     │
│ - Built-in + custom evaluator registration                  │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ LAYER 4: Evaluator Classes                                  │
│ - BaseEvaluator (automated)                                 │
│ - LlmJudgeEvaluator (LLM-based)                            │
│ - Built-in: Length, Format, Keyword                         │
│ - Custom: User-defined evaluators                           │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ LAYER 5: Background Jobs                                    │
│ - EvaluationJob (async evaluation execution)                │
│ - AutoEvaluationJob (triggered on response creation)        │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ LAYER 6: Data Layer                                         │
│ - Evaluation model (stores results)                         │
│ - EvaluatorConfig model (prompt-level settings)             │
│ - LlmResponse model (triggers auto-evaluation)              │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

#### Manual Evaluation (Human)
```
User fills form → Controller saves → Evaluation created ✅
```

#### Manual Evaluation (Automated)
```
User selects evaluator → Configures params → Controller runs evaluator → Evaluation created ✅
```

#### Manual Evaluation (LLM Judge)
```
User configures judge → Job enqueued → Background: Call LLM → Parse response → Evaluation created ✅
```

#### Automatic Evaluation
```
LlmResponse created → Callback → Check EvaluatorConfigs → Enqueue jobs → Evaluations created ✅
```

---

## Core Components

### 1. Evaluator Registry

**Purpose:** Central registry for discovering and managing evaluators

**Location:** `app/services/prompt_tracker/evaluator_registry.rb`

**Responsibilities:**
- Register built-in evaluators
- Allow custom evaluator registration
- Provide evaluator metadata (name, description, config schema)
- List available evaluators by type
- Validate evaluator classes

**API:**
```ruby
# Register an evaluator
PromptTracker::EvaluatorRegistry.register(
  key: :length_check,
  name: "Length Validator",
  description: "Checks if response length is within acceptable range",
  type: :automated,
  class_name: "PromptTracker::Evaluators::LengthEvaluator",
  config_schema: {
    min_length: { type: :integer, default: 0, description: "Minimum character count" },
    max_length: { type: :integer, default: 1000, description: "Maximum character count" },
    ideal_min: { type: :integer, optional: true, description: "Ideal minimum length" },
    ideal_max: { type: :integer, optional: true, description: "Ideal maximum length" }
  },
  icon: "bi-rulers"
)

# Get all evaluators
PromptTracker::EvaluatorRegistry.all
# => [{ key: :length_check, name: "Length Validator", ... }, ...]

# Get evaluators by type
PromptTracker::EvaluatorRegistry.automated
PromptTracker::EvaluatorRegistry.llm_judges

# Get evaluator metadata
PromptTracker::EvaluatorRegistry.get(:length_check)
# => { key: :length_check, name: "Length Validator", config_schema: {...}, ... }

# Instantiate evaluator
evaluator = PromptTracker::EvaluatorRegistry.build(:length_check, response, config)
```

### 2. Evaluator Orchestrator

**Purpose:** Executes evaluators and handles results

**Location:** `app/services/prompt_tracker/evaluator_orchestrator.rb`

**Responsibilities:**
- Run automated evaluators synchronously
- Enqueue LLM judge evaluators asynchronously
- Handle errors and retries
- Store evaluation results

**API:**
```ruby
# Run an automated evaluator
orchestrator = PromptTracker::EvaluatorOrchestrator.new(llm_response)
evaluation = orchestrator.run_automated(:length_check, config: { min_length: 50 })

# Run LLM judge (async)
job_id = orchestrator.run_llm_judge(:gpt4_judge, config: { criteria: ["accuracy"] })

# Run multiple evaluators
evaluations = orchestrator.run_all([
  { type: :automated, key: :length_check, config: {...} },
  { type: :llm_judge, key: :gpt4_judge, config: {...} }
])
```

### 3. Auto Evaluation Service

**Purpose:** Automatically trigger evaluations based on prompt configuration

**Location:** `app/services/prompt_tracker/auto_evaluation_service.rb`

**Responsibilities:**
- Check if prompt has auto-evaluation configured
- Trigger configured evaluators when response is created
- Handle evaluation scheduling and prioritization

**API:**
```ruby
# Trigger auto-evaluations for a response
PromptTracker::AutoEvaluationService.evaluate(llm_response)

# Configure auto-evaluation for a prompt
prompt.evaluator_configs.create!(
  evaluator_key: :length_check,
  enabled: true,
  config: { min_length: 50, max_length: 500 },
  run_mode: :async  # or :sync
)
```

### 4. Evaluator Config Model

**Purpose:** Store prompt-level evaluator configuration

**Location:** `app/models/prompt_tracker/evaluator_config.rb`

**Schema:**
```ruby
create_table :prompt_tracker_evaluator_configs do |t|
  t.references :prompt, null: false, foreign_key: { to_table: :prompt_tracker_prompts }
  t.string :evaluator_key, null: false  # e.g., "length_check"
  t.boolean :enabled, default: true
  t.jsonb :config, default: {}          # Evaluator-specific configuration
  t.string :run_mode, default: "async"  # "sync" or "async"
  t.integer :priority, default: 0       # Higher = runs first
  t.timestamps
end
```

---

## Multi-Evaluator Pattern & Score Aggregation

### Core Principle: Multiple Evaluations per Response

**Key Design Decision:** Each LLM response can have **multiple evaluations**, with each evaluator providing its own independent score and feedback.

#### Why Multiple Evaluators?

**1. Separation of Concerns**
```ruby
# Each evaluator focuses on ONE specific aspect
response.evaluations
  # => LengthEvaluator: 95/100 (247 chars, within ideal range)
  # => KeywordEvaluator: 100/100 (all required keywords present)
  # => SentimentEvaluator: 70/100 (slightly negative tone)
  # => LlmJudgeEvaluator: 85/100 (GPT-4 overall quality assessment)

# NOT a single mega-evaluator trying to do everything
# => CompositeEvaluator: 87.5/100 (how was this calculated? what failed?)
```

**2. Granular Insights**
You can identify **exactly which aspect** needs improvement:
- ✅ Length: Perfect (100/100)
- ✅ Keywords: All present (100/100)
- ⚠️ Sentiment: **This is the problem!** (70/100)
- ✅ Overall Quality: Good (85/100)

**3. Flexible Composition**
Different prompts need different evaluation criteria:

```ruby
# Customer support prompt - focus on tone and helpfulness
customer_support_prompt.evaluator_configs:
  - SentimentEvaluator (weight: 0.4) - Must be positive
  - LengthEvaluator (weight: 0.2) - Concise responses
  - KeywordEvaluator (weight: 0.4) - Must include "thank you"

# Technical documentation prompt - focus on accuracy and completeness
tech_docs_prompt.evaluator_configs:
  - FormatEvaluator (weight: 0.3) - Must be valid Markdown
  - LengthEvaluator (weight: 0.2) - Detailed responses
  - LlmJudgeEvaluator (weight: 0.5) - Technical accuracy
```

**4. Progressive Enhancement**
Start simple, add evaluators over time:

```ruby
# Week 1: Basic validation
prompt.evaluator_configs.create!(evaluator_key: :length_check)

# Week 2: Add keyword checking
prompt.evaluator_configs.create!(evaluator_key: :keyword_check)

# Week 3: Add AI-powered quality assessment
prompt.evaluator_configs.create!(evaluator_key: :gpt4_judge)

# Week 4: Add custom business logic
prompt.evaluator_configs.create!(evaluator_key: :custom_compliance_check)
```

### Score Aggregation Strategies

Since each response has multiple evaluations, you need a strategy to calculate an **overall score**.

#### Strategy 1: Simple Average

```ruby
# app/models/prompt_tracker/llm_response.rb
def overall_score
  evaluations.average(:score)&.round(2) || 0
end

# Example:
# Length: 95, Keywords: 100, Sentiment: 70, LLM Judge: 85
# Overall: (95 + 100 + 70 + 85) / 4 = 87.5
```

**Pros:** Simple, easy to understand
**Cons:** All evaluators weighted equally (may not reflect importance)

#### Strategy 2: Weighted Average

```ruby
# app/models/prompt_tracker/llm_response.rb
def overall_score(weights: nil)
  weights ||= prompt&.evaluator_weights || default_weights

  total_weight = 0
  weighted_sum = 0

  evaluations.each do |evaluation|
    weight = weights[evaluation.evaluator_id.to_sym] || 1.0
    weighted_sum += evaluation.score * weight
    total_weight += weight
  end

  total_weight > 0 ? (weighted_sum / total_weight).round(2) : 0
end

private

def default_weights
  {
    length_check: 0.2,
    keyword_check: 0.3,
    sentiment_check: 0.2,
    gpt4_judge: 0.3
  }
end

# Example with weights:
# Length: 95 * 0.2 = 19
# Keywords: 100 * 0.3 = 30
# Sentiment: 70 * 0.2 = 14
# LLM Judge: 85 * 0.3 = 25.5
# Overall: (19 + 30 + 14 + 25.5) / 1.0 = 88.5
```

**Pros:** Reflects importance of different criteria
**Cons:** Requires configuration of weights

#### Strategy 3: Minimum Score (All Must Pass)

```ruby
# app/models/prompt_tracker/llm_response.rb
def overall_score
  evaluations.minimum(:score) || 0
end

# Example:
# Length: 95, Keywords: 100, Sentiment: 70, LLM Judge: 85
# Overall: 70 (lowest score)
```

**Pros:** Ensures all criteria meet minimum standards
**Cons:** One low score tanks the overall rating

#### Strategy 4: Tiered Evaluation (Dependencies)

```ruby
# app/models/prompt_tracker/llm_response.rb
def overall_score
  # Tier 1: Basic checks (must pass)
  length_eval = evaluations.find_by(evaluator_id: 'length_check')
  keyword_eval = evaluations.find_by(evaluator_id: 'keyword_check')

  return 0 unless length_eval&.score.to_i >= 80
  return 0 unless keyword_eval&.score.to_i >= 90

  # Tier 2: Quality checks (if basic checks pass)
  sentiment_eval = evaluations.find_by(evaluator_id: 'sentiment_check')
  judge_eval = evaluations.find_by(evaluator_id: 'gpt4_judge')

  # Return weighted average of quality checks
  ((sentiment_eval&.score.to_f || 0) * 0.4 +
   (judge_eval&.score.to_f || 0) * 0.6).round(2)
end

# Example:
# If length < 80 OR keywords < 90: Overall = 0 (fail fast)
# Otherwise: Overall = (sentiment * 0.4) + (judge * 0.6)
```

**Pros:** Enforces prerequisites, prevents wasted LLM calls
**Cons:** More complex logic

#### Strategy 5: Custom Business Logic

```ruby
# app/models/prompt_tracker/prompt.rb
class Prompt < ApplicationRecord
  # Store custom aggregation logic as a proc
  def score_aggregation_strategy
    case category
    when "customer_support"
      ->(evals) {
        # Sentiment is critical for support
        sentiment = evals.find { |e| e.evaluator_id == 'sentiment_check' }&.score || 0
        return 0 if sentiment < 70
        evals.average(:score)
      }
    when "technical_docs"
      ->(evals) {
        # Format and accuracy are critical
        format = evals.find { |e| e.evaluator_id == 'format_check' }&.score || 0
        judge = evals.find { |e| e.evaluator_id == 'gpt4_judge' }&.score || 0
        [format, judge].min
      }
    else
      ->(evals) { evals.average(:score) }
    end
  end
end

# app/models/prompt_tracker/llm_response.rb
def overall_score
  strategy = prompt&.score_aggregation_strategy || ->(evals) { evals.average(:score) }
  strategy.call(evaluations).to_f.round(2)
end
```

**Pros:** Maximum flexibility per prompt type
**Cons:** Requires careful design and testing

### Recommended Approach

**Start with Strategy 2 (Weighted Average)** with configurable weights:

```ruby
# Add to evaluator_configs table
add_column :prompt_tracker_evaluator_configs, :weight, :decimal, default: 1.0

# Configure per prompt
prompt.evaluator_configs.create!(
  evaluator_key: :sentiment_check,
  weight: 0.4,  # 40% of overall score
  enabled: true
)
```

This provides:
- ✅ Flexibility to adjust importance
- ✅ Simple to understand and explain
- ✅ Easy to configure in UI
- ✅ Can evolve to more complex strategies later

---

## UI/UX Design

### Design Principles

1. **Progressive Disclosure** - Show complexity only when needed
2. **Type-Aware Forms** - Different forms for different evaluator types
3. **Immediate Feedback** - Show evaluation results in real-time
4. **Consistent with PromptTracker Design System** - Use existing Bootstrap 5.3 components, icons, and styling
5. **Developer-Friendly** - Technical, data-driven aesthetic

### Color Palette (from existing design system)

- **Primary:** `#007BFF` (Electric Blue) - Actions, links
- **Success:** `#00D97E` (Neon Green) - Successful evaluations
- **Warning:** `#FFC107` - Medium scores
- **Danger:** `#DC3545` - Failed evaluations
- **Info:** `#17A2B8` - Informational
- **Gray:** `#6B7280` - Secondary text

### UI Components

#### 1. Evaluation Type Selector (Step 1)

**Location:** Response show page, collapsible card

**Design:**
```
┌─────────────────────────────────────────────────────────┐
│ 📊 Add New Evaluation                              [▼]  │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ Choose Evaluation Type:                                │
│                                                         │
│ ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
│ │ 👤 Human    │  │ 🤖 Automated│  │ 🧠 LLM Judge│    │
│ │             │  │             │  │             │    │
│ │ Manual      │  │ Rule-based  │  │ AI-powered  │    │
│ │ review      │  │ scoring     │  │ evaluation  │    │
│ │             │  │             │  │             │    │
│ │ [Select]    │  │ [Select]    │  │ [Select]    │    │
│ └─────────────┘  └─────────────┘  └─────────────┘    │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Implementation:**
- Three large, clickable cards
- Icons from Bootstrap Icons
- Hover effect with border highlight
- Click transitions to type-specific form

#### 2. Human Evaluation Form

**Design:**
```
┌─────────────────────────────────────────────────────────┐
│ 👤 Human Evaluation                            [← Back] │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ Evaluator Email *                                       │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ john@example.com                                    │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│ Overall Score *                                         │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ 4.5                                                 │ │
│ └─────────────────────────────────────────────────────┘ │
│ ├─────────────────────────────────────────────────────┤ │
│ 0                    2.5                    5          │
│ Range: 0 - 5                                           │
│                                                         │
│ Criteria Scores (Optional)                             │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ Helpfulness:  [5  ] ⭐⭐⭐⭐⭐                        │ │
│ │ Accuracy:     [4.5] ⭐⭐⭐⭐☆                        │ │
│ │ Tone:         [4  ] ⭐⭐⭐⭐☆                        │ │
│ │ + Add Criterion                                     │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│ Feedback                                                │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ Great response! Very helpful and accurate.          │ │
│ │ Could be slightly more concise.                     │ │
│ │                                                     │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│ [Cancel]                          [Create Evaluation]  │
└─────────────────────────────────────────────────────────┘
```

**Features:**
- Email input with validation
- Score slider with live preview
- Dynamic criteria addition
- Star rating visualization
- Rich text feedback area

#### 3. Automated Evaluation Form

**Design:**
```
┌─────────────────────────────────────────────────────────┐
│ 🤖 Automated Evaluation                        [← Back] │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ Select Evaluator *                                      │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ 📏 Length Validator                             [▼] │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│ ℹ️ Checks if response length is within acceptable range │
│                                                         │
│ Configuration                                           │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ Minimum Length (characters)                         │ │
│ │ ┌─────────────────────────────────────────────────┐ │ │
│ │ │ 50                                              │ │ │
│ │ └─────────────────────────────────────────────────┘ │ │
│ │                                                     │ │
│ │ Maximum Length (characters)                         │ │
│ │ ┌─────────────────────────────────────────────────┐ │ │
│ │ │ 500                                             │ │ │
│ │ └─────────────────────────────────────────────────┘ │ │
│ │                                                     │ │
│ │ Ideal Range (Optional)                              │ │
│ │ ┌──────────────────┐  ┌──────────────────┐         │ │
│ │ │ Min: 100         │  │ Max: 300         │         │ │
│ │ └──────────────────┘  └──────────────────┘         │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│ 🔍 Preview                                              │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ Current response: 247 characters                    │ │
│ │ ✅ Within acceptable range (50-500)                 │ │
│ │ ✅ Within ideal range (100-300)                     │ │
│ │ Estimated score: 100/100                            │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│ [Cancel]                          [Run Evaluation]     │
└─────────────────────────────────────────────────────────┘
```

**Features:**
- Evaluator dropdown with descriptions
- Dynamic configuration form (changes based on selected evaluator)
- Live preview of evaluation result
- "Run Evaluation" button (executes immediately)
- Shows estimated score before running

#### 4. LLM Judge Evaluation Form

**Design:**
```
┌─────────────────────────────────────────────────────────┐
│ 🧠 LLM Judge Evaluation                        [← Back] │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ Judge Model *                                           │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ GPT-4                                           [▼] │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│ Evaluation Criteria *                                   │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ ☑ Accuracy      - Factually correct?               │ │
│ │ ☑ Helpfulness   - Addresses user needs?            │ │
│ │ ☑ Tone          - Appropriate and professional?    │ │
│ │ ☐ Clarity       - Clear and understandable?        │ │
│ │ ☐ Completeness  - Fully addresses question?        │ │
│ │ ☐ Conciseness   - No unnecessary information?      │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│ Custom Instructions (Optional)                          │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ Focus on technical accuracy for a developer         │ │
│ │ audience. Be strict about security issues.          │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│ Score Range                                             │
│ ┌──────────────────┐  ┌──────────────────┐            │
│ │ Min: 0           │  │ Max: 5           │            │
│ └──────────────────┘  └──────────────────┘            │
│                                                         │
│ ⚠️ This will call the GPT-4 API and may take 5-10s     │
│                                                         │
│ [Cancel]                    [Run Evaluation (Async)]   │
└─────────────────────────────────────────────────────────┘
```

**Features:**
- Judge model selector (GPT-4, Claude, etc.)
- Checkbox list of criteria with descriptions
- Custom instructions textarea
- Score range configuration
- Warning about API call and timing
- "Run Evaluation (Async)" button - shows job status

#### 5. Evaluation Breakdown Scorecard (Multi-Evaluator Display)

**Location:** Response show page, evaluations section

**Design:**
```
┌─────────────────────────────────────────────────────────────────┐
│ 📊 Evaluations                                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ Overall Score: 87.5/100                              [⭐⭐⭐⭐☆] │
│ Based on 4 evaluations (weighted average)                      │
│                                                                 │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ ✅ Length Validator                    95/100  [█████████▒] │ │
│ │    Weight: 20% | Automated | 2 min ago                     │ │
│ │    📝 Response length: 247 characters (ideal: 100-300)     │ │
│ │    ✅ Within acceptable range (50-500)                     │ │
│ │    ✅ Within ideal range (100-300)                         │ │
│ └─────────────────────────────────────────────────────────────┘ │
│                                                                 │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ ✅ Keyword Checker                    100/100  [██████████] │ │
│ │    Weight: 30% | Automated | 2 min ago                     │ │
│ │    📝 All required keywords present                        │ │
│ │    ✅ Found: "hello", "welcome", "assist"                  │ │
│ │    ✅ No forbidden keywords detected                       │ │
│ └─────────────────────────────────────────────────────────────┘ │
│                                                                 │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ ⚠️  Sentiment Analyzer                 70/100  [███████▒▒▒] │ │
│ │    Weight: 20% | Automated | 2 min ago                     │ │
│ │    📝 Response sentiment: Neutral (slightly negative)      │ │
│ │    ⚠️  Detected negative words: "unfortunately", "cannot"  │ │
│ │    💡 Suggestion: Use more positive language               │ │
│ └─────────────────────────────────────────────────────────────┘ │
│                                                                 │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ ✅ GPT-4 Judge                         85/100  [████████▒▒] │ │
│ │    Weight: 30% | LLM Judge | 1 min ago                     │ │
│ │    📝 Good response overall. Addresses the question        │ │
│ │       clearly and provides helpful information. Could      │ │
│ │       be more positive in tone.                            │ │
│ │                                                             │ │
│ │    Criteria Breakdown:                                      │ │
│ │    • Accuracy: 90/100 ⭐⭐⭐⭐⭐                              │ │
│ │    • Helpfulness: 85/100 ⭐⭐⭐⭐☆                           │ │
│ │    • Tone: 75/100 ⭐⭐⭐⭐☆                                  │ │
│ │    • Clarity: 90/100 ⭐⭐⭐⭐⭐                              │ │
│ └─────────────────────────────────────────────────────────────┘ │
│                                                                 │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ 👤 Human Review                        80/100  [████████▒▒] │ │
│ │    sarah@company.com | 5 hours ago                         │ │
│ │    📝 Good response but could be friendlier. The           │ │
│ │       information is accurate and helpful.                 │ │
│ │                                                             │ │
│ │    Criteria Breakdown:                                      │ │
│ │    • Helpfulness: 90/100 ⭐⭐⭐⭐⭐                          │ │
│ │    • Accuracy: 85/100 ⭐⭐⭐⭐☆                              │ │
│ │    • Tone: 65/100 ⭐⭐⭐☆☆                                  │ │
│ └─────────────────────────────────────────────────────────────┘ │
│                                                                 │
│ [+ Add New Evaluation]                                         │
└─────────────────────────────────────────────────────────────────┘
```

**Features:**
- **Overall score at top** with visual rating (stars)
- **Aggregation method shown** (weighted average, simple average, etc.)
- **Each evaluation in its own card** with:
  - Icon indicating status (✅ pass, ⚠️ warning, ❌ fail)
  - Evaluator name and score with progress bar
  - Weight percentage (if using weighted average)
  - Type (Automated/LLM Judge/Human) and timestamp
  - Detailed feedback
  - Criteria breakdown (if available)
  - Actionable suggestions
- **Color coding:**
  - Green (✅): Score ≥ 80
  - Yellow (⚠️): Score 60-79
  - Red (❌): Score < 60
- **Expandable/collapsible** cards for detailed feedback
- **Sorted by priority** or timestamp

#### 6. Evaluation Status Indicator (for async evaluations)

**Design:**
```
┌─────────────────────────────────────────────────────────┐
│ 🧠 LLM Judge Evaluation - In Progress                   │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ ⏳ Calling GPT-4 API...                                 │
│                                                         │
│ ████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ 30%      │
│                                                         │
│ Status: Waiting for judge response                      │
│ Started: 2 seconds ago                                  │
│                                                         │
│ [View Job Details]                                      │
└─────────────────────────────────────────────────────────┘
```

**Features:**
- Real-time progress bar
- Status updates via WebSocket or polling
- Link to job details
- Auto-refresh when complete

#### 7. Prompt-Level Evaluator Configuration with Weights

**Location:** Prompt show page, "Auto-Evaluation" tab

**Design:**
```
┌─────────────────────────────────────────────────────────┐
│ Prompt: customer_greeting                               │
│ [Overview] [Versions] [Analytics] [Auto-Evaluation]     │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ ⚙️ Automatic Evaluation Configuration                   │
│                                                         │
│ Configure evaluators to run automatically when          │
│ responses are created for this prompt.                  │
│                                                         │
│ Score Aggregation: [Weighted Average ▼]                │
│                                                         │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ Configured Evaluators (Total Weight: 100%)         │ │
│ │                                                     │ │
│ │ ┌─────────────────────────────────────────────────┐ │ │
│ │ │ 📏 Length Validator                  [Enabled]  │ │ │
│ │ │ Weight: [20%] ████░░░░░░░░░░░░░░░░░░░░░░░░░░░  │ │ │
│ │ │ Min: 50, Max: 500, Ideal: 100-300              │ │ │
│ │ │ Mode: Sync | Priority: 1                       │ │ │
│ │ │ [Edit] [Disable] [Delete] [↑] [↓]             │ │ │
│ │ └─────────────────────────────────────────────────┘ │ │
│ │                                                     │ │
│ │ ┌─────────────────────────────────────────────────┐ │ │
│ │ │ 🔑 Keyword Check                     [Enabled]  │ │ │
│ │ │ Weight: [30%] ██████░░░░░░░░░░░░░░░░░░░░░░░░░  │ │ │
│ │ │ Required: ["hello", "welcome"]                 │ │ │
│ │ │ Mode: Sync | Priority: 2                       │ │ │
│ │ │ [Edit] [Disable] [Delete] [↑] [↓]             │ │ │
│ │ └─────────────────────────────────────────────────┘ │ │
│ │                                                     │ │
│ │ ┌─────────────────────────────────────────────────┐ │ │
│ │ │ 😊 Sentiment Analyzer                [Enabled]  │ │ │
│ │ │ Weight: [20%] ████░░░░░░░░░░░░░░░░░░░░░░░░░░░  │ │ │
│ │ │ Positive keywords: ["great", "happy"]          │ │ │
│ │ │ Mode: Async | Priority: 3                      │ │ │
│ │ │ [Edit] [Disable] [Delete] [↑] [↓]             │ │ │
│ │ └─────────────────────────────────────────────────┘ │ │
│ │                                                     │ │
│ │ ┌─────────────────────────────────────────────────┐ │ │
│ │ │ 🧠 GPT-4 Judge                       [Enabled]  │ │ │
│ │ │ Weight: [30%] ██████░░░░░░░░░░░░░░░░░░░░░░░░░  │ │ │
│ │ │ Criteria: accuracy, helpfulness, tone          │ │ │
│ │ │ Mode: Async | Priority: 4                      │ │ │
│ │ │ [Edit] [Disable] [Delete] [↑] [↓]             │ │ │
│ │ └─────────────────────────────────────────────────┘ │ │
│ │                                                     │ │
│ │ [+ Add Evaluator]                                   │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│ 📊 Evaluation History (Last 30 Days)                    │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ Total Responses: 1,234                              │ │
│ │ Auto-Evaluated: 1,234 (100%)                        │ │
│ │ Average Overall Score: 87.5/100                     │ │
│ │ Average by Evaluator:                               │ │
│ │   • Length: 92.3/100                                │ │
│ │   • Keywords: 95.8/100                              │ │
│ │   • Sentiment: 78.4/100 ⚠️ (needs improvement)      │ │
│ │   • GPT-4 Judge: 86.1/100                           │ │
│ │ Failed Evaluations: 12 (1%)                         │ │
│ └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

**Features:**
- **Score aggregation strategy selector** (weighted average, simple average, minimum, custom)
- **Weight sliders** for each evaluator (visual + numeric)
- **Total weight indicator** (must equal 100% for weighted average)
- **Drag-and-drop reordering** (↑↓ buttons or drag handles)
- **Enable/disable toggle** per evaluator
- **Statistics showing average scores** per evaluator
- **Warnings** for evaluators with low average scores
- **Visual weight distribution** (progress bars)

---

## User Workflows

### Workflow 1: Manual Human Evaluation

**Actor:** Product Manager / QA Reviewer

**Steps:**
1. Navigate to response show page (`/responses/123`)
2. Scroll to "Evaluations" section
3. Click "Add New Evaluation"
4. Click "Human" card
5. Fill in:
   - Email: `sarah@company.com`
   - Score: `4.5` (using slider)
   - Criteria: Helpfulness (5), Accuracy (4.5), Tone (4)
   - Feedback: "Great response, very helpful!"
6. Click "Create Evaluation"
7. See evaluation appear in table immediately
8. Receive success notification

**Time:** ~30 seconds

### Workflow 2: Manual Automated Evaluation

**Actor:** Developer / Data Scientist

**Steps:**
1. Navigate to response show page
2. Click "Add New Evaluation"
3. Click "Automated" card
4. Select evaluator: "Length Validator"
5. Configure:
   - Min: 50
   - Max: 500
   - Ideal: 100-300
6. See live preview: "Current: 247 chars, Score: 100/100"
7. Click "Run Evaluation"
8. Evaluation executes immediately (< 100ms)
9. See result in table with score and feedback

**Time:** ~20 seconds

### Workflow 3: Manual LLM Judge Evaluation

**Actor:** ML Engineer / Quality Lead

**Steps:**
1. Navigate to response show page
2. Click "Add New Evaluation"
3. Click "LLM Judge" card
4. Select judge model: "GPT-4"
5. Select criteria: Accuracy, Helpfulness, Tone
6. Add custom instructions: "Focus on technical accuracy"
7. Click "Run Evaluation (Async)"
8. See job status: "⏳ Calling GPT-4 API..."
9. Page shows progress indicator
10. After 5-10 seconds, evaluation completes
11. See result with score, criteria breakdown, and feedback

**Time:** ~30 seconds + 5-10s API call

### Workflow 4: Configure Auto-Evaluation for Prompt

**Actor:** Developer / Team Lead

**Steps:**
1. Navigate to prompt show page (`/prompts/customer_greeting`)
2. Click "Auto-Evaluation" tab
3. Click "+ Add Evaluator"
4. Select "Length Validator"
5. Configure:
   - Min: 50, Max: 500
   - Mode: Async
   - Priority: 1
6. Click "Save"
7. Toggle "Enabled"
8. From now on, all new responses automatically get evaluated

**Time:** ~1 minute (one-time setup)

### Workflow 5: Automatic Evaluation (Background)

**Actor:** System (automatic)

**Trigger:** New LLM response created

**Steps:**
1. `LlmResponse.create!` called
2. `after_create` callback fires
3. `AutoEvaluationService.evaluate(response)` called
4. Service checks `prompt.evaluator_configs.enabled`
5. For each enabled config:
   - If sync: Run evaluator immediately
   - If async: Enqueue `EvaluationJob`
6. Jobs execute in background
7. Evaluations created and visible in UI

**Time:** Immediate (async) or < 1s (sync)

---

## Technical Implementation

### Phase 1: Evaluator Registry (Week 1)

**Files to Create:**
- `app/services/prompt_tracker/evaluator_registry.rb`
- `test/services/prompt_tracker/evaluator_registry_test.rb`

**Implementation:**
```ruby
module PromptTracker
  class EvaluatorRegistry
    class << self
      def register(key:, name:, description:, type:, class_name:, config_schema:, icon: nil)
        @evaluators ||= {}
        @evaluators[key.to_sym] = {
          key: key.to_sym,
          name: name,
          description: description,
          type: type.to_sym,
          class_name: class_name,
          config_schema: config_schema,
          icon: icon || default_icon(type)
        }
      end

      def all
        @evaluators&.values || []
      end

      def automated
        all.select { |e| e[:type] == :automated }
      end

      def llm_judges
        all.select { |e| e[:type] == :llm_judge }
      end

      def get(key)
        @evaluators&.[](key.to_sym)
      end

      def build(key, llm_response, config = {})
        metadata = get(key)
        raise ArgumentError, "Unknown evaluator: #{key}" unless metadata

        klass = metadata[:class_name].constantize
        klass.new(llm_response, config)
      end

      private

      def default_icon(type)
        case type
        when :automated then "bi-robot"
        when :llm_judge then "bi-brain"
        else "bi-gear"
        end
      end
    end
  end
end
```

---

### Phase 2: Database Schema & Models (Week 1)

**Migration:**
```ruby
# db/migrate/XXXXXX_create_evaluator_configs.rb
class CreateEvaluatorConfigs < ActiveRecord::Migration[7.0]
  def change
    create_table :prompt_tracker_evaluator_configs do |t|
      t.references :prompt, null: false, foreign_key: { to_table: :prompt_tracker_prompts }
      t.string :evaluator_key, null: false
      t.boolean :enabled, default: true
      t.jsonb :config, default: {}
      t.string :run_mode, default: "async"
      t.integer :priority, default: 0
      t.decimal :weight, precision: 5, scale: 2, default: 1.0
      t.string :depends_on  # Optional: evaluator_key that must pass first
      t.integer :min_dependency_score  # Minimum score required from dependency
      t.timestamps
    end

    add_index :prompt_tracker_evaluator_configs, [:prompt_id, :evaluator_key],
              unique: true, name: "index_evaluator_configs_on_prompt_and_key"
    add_index :prompt_tracker_evaluator_configs, :enabled
    add_index :prompt_tracker_evaluator_configs, :depends_on
  end
end

# Add aggregation strategy to prompts
class AddAggregationStrategyToPrompts < ActiveRecord::Migration[7.0]
  def change
    add_column :prompt_tracker_prompts, :score_aggregation_strategy, :string, default: "weighted_average"
  end
end
```

**Model:**
```ruby
# app/models/prompt_tracker/evaluator_config.rb
module PromptTracker
  class EvaluatorConfig < ApplicationRecord
    belongs_to :prompt

    validates :evaluator_key, presence: true, uniqueness: { scope: :prompt_id }
    validates :run_mode, inclusion: { in: %w[sync async] }
    validates :priority, numericality: { only_integer: true }
    validates :weight, numericality: { greater_than_or_equal_to: 0 }
    validates :min_dependency_score, numericality: { only_integer: true, allow_nil: true }

    scope :enabled, -> { where(enabled: true) }
    scope :by_priority, -> { order(priority: :desc) }
    scope :independent, -> { where(depends_on: nil) }
    scope :dependent, -> { where.not(depends_on: nil) }

    def evaluator_metadata
      EvaluatorRegistry.get(evaluator_key)
    end

    def build_evaluator(llm_response)
      EvaluatorRegistry.build(evaluator_key, llm_response, config)
    end

    def sync?
      run_mode == "sync"
    end

    def async?
      run_mode == "async"
    end

    def has_dependency?
      depends_on.present?
    end

    def dependency_met?(llm_response)
      return true unless has_dependency?

      dependency_eval = llm_response.evaluations.find_by(evaluator_id: depends_on)
      return false unless dependency_eval

      min_score = min_dependency_score || 80
      dependency_eval.score >= min_score
    end

    def normalized_weight
      # Normalize weight relative to all enabled configs for this prompt
      total_weight = prompt.evaluator_configs.enabled.sum(:weight)
      total_weight > 0 ? (weight / total_weight) : 0
    end
  end
end
```

**Update Prompt Model:**
```ruby
# app/models/prompt_tracker/prompt.rb
module PromptTracker
  class Prompt < ApplicationRecord
    has_many :evaluator_configs, dependent: :destroy

    AGGREGATION_STRATEGIES = %w[
      simple_average
      weighted_average
      minimum
      custom
    ].freeze

    validates :score_aggregation_strategy, inclusion: { in: AGGREGATION_STRATEGIES }, allow_nil: true

    # ... existing code ...
  end
end
```

**Update LlmResponse Model with Score Aggregation:**
```ruby
# app/models/prompt_tracker/llm_response.rb
module PromptTracker
  class LlmResponse < ApplicationRecord
    after_create :trigger_auto_evaluation

    # ... existing code ...

    # Calculate overall score based on prompt's aggregation strategy
    def overall_score
      return 0 if evaluations.empty?

      strategy = prompt&.score_aggregation_strategy || "simple_average"

      case strategy
      when "simple_average"
        calculate_simple_average
      when "weighted_average"
        calculate_weighted_average
      when "minimum"
        calculate_minimum_score
      when "custom"
        calculate_custom_score
      else
        calculate_simple_average
      end
    end

    # Get breakdown of all evaluation scores
    def evaluation_breakdown
      evaluations.map do |eval|
        config = prompt&.evaluator_configs&.find_by(evaluator_key: eval.evaluator_id)
        {
          evaluator_id: eval.evaluator_id,
          evaluator_name: config&.evaluator_metadata&.dig(:name) || eval.evaluator_id,
          score: eval.score,
          weight: config&.weight || 1.0,
          normalized_weight: config&.normalized_weight || 0,
          feedback: eval.feedback,
          criteria_scores: eval.criteria_scores,
          created_at: eval.created_at
        }
      end
    end

    # Check if response passes all evaluations above threshold
    def passes_threshold?(threshold = 80)
      evaluations.all? { |eval| eval.score >= threshold }
    end

    # Get lowest scoring evaluation
    def weakest_evaluation
      evaluations.min_by(&:score)
    end

    # Get highest scoring evaluation
    def strongest_evaluation
      evaluations.max_by(&:score)
    end

    private

    def trigger_auto_evaluation
      AutoEvaluationService.evaluate(self)
    end

    def calculate_simple_average
      evaluations.average(:score)&.round(2) || 0
    end

    def calculate_weighted_average
      return calculate_simple_average unless prompt

      total_weight = 0
      weighted_sum = 0

      evaluations.each do |evaluation|
        config = prompt.evaluator_configs.find_by(evaluator_key: evaluation.evaluator_id)
        weight = config&.weight || 1.0

        weighted_sum += evaluation.score * weight
        total_weight += weight
      end

      total_weight > 0 ? (weighted_sum / total_weight).round(2) : 0
    end

    def calculate_minimum_score
      evaluations.minimum(:score) || 0
    end

    def calculate_custom_score
      # Override this method in your application if needed
      # Or store custom logic in prompt.metadata
      calculate_weighted_average
    end
  end
end
```

---

### Phase 3: Auto-Evaluation Service (Week 2)

**Files to Create:**
- `app/services/prompt_tracker/auto_evaluation_service.rb`
- `app/jobs/prompt_tracker/evaluation_job.rb`
- `test/services/prompt_tracker/auto_evaluation_service_test.rb`

**Service Implementation:**
```ruby
# app/services/prompt_tracker/auto_evaluation_service.rb
module PromptTracker
  class AutoEvaluationService
    def self.evaluate(llm_response)
      new(llm_response).evaluate
    end

    def initialize(llm_response)
      @llm_response = llm_response
      @prompt = llm_response.prompt
    end

    def evaluate
      return unless @prompt

      # Run independent evaluators first
      independent_configs = @prompt.evaluator_configs.enabled.independent.by_priority
      independent_configs.each { |config| run_evaluation(config) }

      # Then run dependent evaluators (only if dependencies are met)
      dependent_configs = @prompt.evaluator_configs.enabled.dependent.by_priority
      dependent_configs.each do |config|
        next unless config.dependency_met?(@llm_response)
        run_evaluation(config)
      end
    end

    private

    def run_evaluation(config)
      if config.sync?
        run_sync_evaluation(config)
      else
        run_async_evaluation(config)
      end
    end

    def run_sync_evaluation(config)
      evaluator = config.build_evaluator(@llm_response)
      result = evaluator.evaluate

      EvaluationService.create_automated(
        llm_response: @llm_response,
        evaluator_id: config.evaluator_key.to_s,
        score: result.score,
        criteria_scores: result.criteria_scores,
        feedback: result.feedback,
        metadata: result.metadata.merge(
          weight: config.weight,
          priority: config.priority
        )
      )
    rescue => e
      Rails.logger.error("Sync evaluation failed for #{config.evaluator_key}: #{e.message}")
      # Don't raise - continue with other evaluators
    end

    def run_async_evaluation(config)
      # For dependent evaluators, pass dependency info to job
      EvaluationJob.perform_later(
        @llm_response.id,
        config.id,
        check_dependency: config.has_dependency?
      )
    end
  end
end
```

**Background Job:**
```ruby
# app/jobs/prompt_tracker/evaluation_job.rb
module PromptTracker
  class EvaluationJob < ApplicationJob
    queue_as :default
    retry_on StandardError, wait: :exponentially_longer, attempts: 3

    def perform(llm_response_id, evaluator_config_id, check_dependency: false)
      llm_response = LlmResponse.find(llm_response_id)
      config = EvaluatorConfig.find(evaluator_config_id)

      # Check dependency if required
      if check_dependency && !config.dependency_met?(llm_response)
        Rails.logger.info(
          "Skipping #{config.evaluator_key} - dependency not met " \
          "(requires #{config.depends_on} >= #{config.min_dependency_score})"
        )
        return
      end

      evaluator = config.build_evaluator(llm_response)

      # For LLM judges, pass a block that calls the API
      result = if evaluator.is_a?(Evaluators::LlmJudgeEvaluator)
        evaluator.evaluate do |prompt|
          call_llm_api(config.config[:judge_model], prompt)
        end
      else
        evaluator.evaluate
      end

      EvaluationService.create_automated(
        llm_response: llm_response,
        evaluator_id: config.evaluator_key.to_s,
        score: result.score,
        criteria_scores: result.criteria_scores,
        feedback: result.feedback,
        metadata: result.metadata.merge(
          job_id: job_id,
          weight: config.weight,
          priority: config.priority,
          dependency: config.depends_on
        )
      )
    end

    private

    def call_llm_api(model, prompt)
      # This would call the actual LLM API
      # Implementation depends on which LLM service is used
      # Example for OpenAI:
      # client = OpenAI::Client.new
      # response = client.chat(
      #   parameters: {
      #     model: model,
      #     messages: [{ role: "user", content: prompt }]
      #   }
      # )
      # response.dig("choices", 0, "message", "content")
    end
  end
end
```

**Update LlmResponse Model:**
```ruby
# app/models/prompt_tracker/llm_response.rb
module PromptTracker
  class LlmResponse < ApplicationRecord
    after_create :trigger_auto_evaluation

    # ... existing code ...

    private

    def trigger_auto_evaluation
      AutoEvaluationService.evaluate(self)
    end
  end
end
```

---

### Evaluation Dependencies & Conditional Execution

**Problem:** Sometimes you want to run expensive evaluations (like LLM judges) **only if** basic checks pass first.

**Solution:** Evaluator dependencies - configure evaluators to run only when prerequisite evaluators pass.

#### Use Cases

**Use Case 1: Skip LLM Judge if Basic Checks Fail**
```ruby
# Only call GPT-4 if response meets basic requirements
prompt.evaluator_configs.create!(
  evaluator_key: :length_check,
  priority: 1,
  run_mode: "sync"
)

prompt.evaluator_configs.create!(
  evaluator_key: :gpt4_judge,
  priority: 2,
  run_mode: "async",
  depends_on: "length_check",      # Must run after length_check
  min_dependency_score: 80          # Only run if length_check >= 80
)

# Result: Save API costs by not calling GPT-4 for invalid responses
```

**Use Case 2: Tiered Evaluation Pipeline**
```ruby
# Tier 1: Format validation (sync, fast)
prompt.evaluator_configs.create!(
  evaluator_key: :format_check,
  priority: 1,
  run_mode: "sync"
)

# Tier 2: Content validation (sync, fast) - only if format is valid
prompt.evaluator_configs.create!(
  evaluator_key: :keyword_check,
  priority: 2,
  run_mode: "sync",
  depends_on: "format_check",
  min_dependency_score: 90
)

# Tier 3: Quality assessment (async, expensive) - only if content is valid
prompt.evaluator_configs.create!(
  evaluator_key: :gpt4_judge,
  priority: 3,
  run_mode: "async",
  depends_on: "keyword_check",
  min_dependency_score: 80
)

# Result: Fast fail for invalid responses, deep evaluation for valid ones
```

**Use Case 3: Human Review Trigger**
```ruby
# Automatically flag for human review if LLM judge scores low
prompt.evaluator_configs.create!(
  evaluator_key: :gpt4_judge,
  priority: 1,
  run_mode: "async"
)

# In your application code:
class LlmResponse < ApplicationRecord
  after_create :check_for_human_review

  private

  def check_for_human_review
    # Wait for LLM judge evaluation (or use webhook/callback)
    judge_eval = evaluations.find_by(evaluator_id: 'gpt4_judge')

    if judge_eval && judge_eval.score < 70
      # Create notification for human reviewer
      HumanReviewNotification.create!(llm_response: self)
    end
  end
end
```

#### Execution Flow with Dependencies

```
Response Created
    ↓
┌─────────────────────────────────────────────────┐
│ Phase 1: Independent Evaluators (Priority Order)│
├─────────────────────────────────────────────────┤
│ ✅ Length Check (sync)        → 95/100          │
│ ✅ Format Check (sync)        → 100/100         │
│ ✅ Keyword Check (sync)       → 85/100          │
└─────────────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────────────┐
│ Phase 2: Dependent Evaluators (Check Dependencies)│
├─────────────────────────────────────────────────┤
│ 🔍 Sentiment Check                              │
│    Depends on: length_check >= 80               │
│    Status: ✅ Dependency met (95 >= 80)         │
│    Result: ✅ Run → 70/100                      │
│                                                 │
│ 🔍 GPT-4 Judge                                  │
│    Depends on: keyword_check >= 90              │
│    Status: ❌ Dependency NOT met (85 < 90)      │
│    Result: ⏭️  Skip (save API cost)             │
└─────────────────────────────────────────────────┘
    ↓
Overall Score: (95 + 100 + 85 + 70) / 4 = 87.5
(GPT-4 not included - didn't run)
```

#### Benefits

1. **Cost Savings** - Don't call expensive LLM APIs for obviously bad responses
2. **Performance** - Fail fast on basic checks
3. **Logical Flow** - Enforce evaluation order (format → content → quality)
4. **Flexibility** - Configure different pipelines per prompt type

---

### Phase 4: Controller Updates (Week 2)

**Update Evaluations Controller:**
```ruby
# app/controllers/prompt_tracker/evaluations_controller.rb
module PromptTracker
  class EvaluationsController < ApplicationController
    before_action :set_response, only: [:create]

    def create
      case params[:evaluator_type]
      when "human"
        create_human_evaluation
      when "automated"
        run_automated_evaluation
      when "llm_judge"
        run_llm_judge_evaluation
      else
        redirect_to llm_response_path(@response), alert: "Invalid evaluator type"
      end
    end

    private

    def set_response
      @response = LlmResponse.find(params[:llm_response_id])
    end

    def create_human_evaluation
      @evaluation = EvaluationService.create_human(
        llm_response: @response,
        evaluator_id: params[:evaluator_email],
        score: params[:score].to_f,
        criteria_scores: parse_criteria_scores(params[:criteria_scores]),
        feedback: params[:feedback]
      )

      if @evaluation.persisted?
        redirect_to llm_response_path(@response), notice: "Evaluation created successfully!"
      else
        redirect_to llm_response_path(@response), alert: "Error: #{@evaluation.errors.full_messages.join(', ')}"
      end
    end

    def run_automated_evaluation
      evaluator_key = params[:evaluator_key]
      config = params[:config] || {}

      evaluator = EvaluatorRegistry.build(evaluator_key, @response, config)
      result = evaluator.evaluate

      @evaluation = EvaluationService.create_automated(
        llm_response: @response,
        evaluator_id: evaluator_key,
        score: result.score,
        criteria_scores: result.criteria_scores,
        feedback: result.feedback,
        metadata: result.metadata
      )

      redirect_to llm_response_path(@response), notice: "Evaluation completed! Score: #{result.score}"
    rescue => e
      redirect_to llm_response_path(@response), alert: "Evaluation failed: #{e.message}"
    end

    def run_llm_judge_evaluation
      evaluator_key = params[:evaluator_key] || :gpt4_judge
      config = {
        judge_model: params[:judge_model],
        criteria: params[:criteria] || [],
        custom_instructions: params[:custom_instructions],
        score_min: params[:score_min]&.to_i || 0,
        score_max: params[:score_max]&.to_i || 5
      }

      # Enqueue async job
      job = EvaluationJob.perform_later(@response.id, evaluator_key, config)

      redirect_to llm_response_path(@response),
                  notice: "LLM Judge evaluation started! Job ID: #{job.job_id}"
    end

    def parse_criteria_scores(criteria_params)
      return {} unless criteria_params

      criteria_params.to_h.transform_values(&:to_f)
    end
  end
end
```

**New Evaluator Configs Controller:**
```ruby
# app/controllers/prompt_tracker/evaluator_configs_controller.rb
module PromptTracker
  class EvaluatorConfigsController < ApplicationController
    before_action :set_prompt
    before_action :set_config, only: [:edit, :update, :destroy, :toggle]

    def index
      @configs = @prompt.evaluator_configs.by_priority
      @available_evaluators = EvaluatorRegistry.all
    end

    def new
      @config = @prompt.evaluator_configs.build
      @available_evaluators = EvaluatorRegistry.all
    end

    def create
      @config = @prompt.evaluator_configs.build(config_params)

      if @config.save
        redirect_to prompt_evaluator_configs_path(@prompt),
                    notice: "Evaluator configured successfully!"
      else
        @available_evaluators = EvaluatorRegistry.all
        render :new
      end
    end

    def edit
      @evaluator_metadata = @config.evaluator_metadata
    end

    def update
      if @config.update(config_params)
        redirect_to prompt_evaluator_configs_path(@prompt),
                    notice: "Configuration updated!"
      else
        render :edit
      end
    end

    def destroy
      @config.destroy
      redirect_to prompt_evaluator_configs_path(@prompt),
                  notice: "Evaluator removed"
    end

    def toggle
      @config.update(enabled: !@config.enabled)
      redirect_to prompt_evaluator_configs_path(@prompt),
                  notice: "Evaluator #{@config.enabled? ? 'enabled' : 'disabled'}"
    end

    private

    def set_prompt
      @prompt = Prompt.find(params[:prompt_id])
    end

    def set_config
      @config = @prompt.evaluator_configs.find(params[:id])
    end

    def config_params
      params.require(:evaluator_config).permit(
        :evaluator_key, :enabled, :run_mode, :priority, config: {}
      )
    end
  end
end
```

**Routes:**
```ruby
# config/routes.rb
PromptTracker::Engine.routes.draw do
  resources :prompts do
    resources :evaluator_configs do
      member do
        patch :toggle
      end
    end
  end

  resources :llm_responses, path: "responses" do
    resources :evaluations, only: [:create]
  end

  # API endpoint for evaluator metadata
  get "evaluators", to: "evaluators#index"
  get "evaluators/:key", to: "evaluators#show"
end
```

---

## Migration Strategy

### Backward Compatibility

**Goal:** Ensure existing evaluations continue to work during transition.

**Approach:**

1. **Keep Existing Form** - Don't remove the current generic form immediately
2. **Add Feature Flag** - Use a feature flag to toggle between old and new UI
3. **Gradual Rollout** - Enable new UI for specific prompts first
4. **Data Migration** - No database changes to existing `evaluations` table needed

### Migration Steps

#### Step 1: Add New Tables (Non-Breaking)
```ruby
# Migration adds new table but doesn't modify existing ones
rails generate migration CreateEvaluatorConfigs
rails db:migrate
```

#### Step 2: Deploy Registry & Services (Non-Breaking)
- Deploy `EvaluatorRegistry`
- Deploy `AutoEvaluationService`
- Deploy `EvaluationJob`
- **No UI changes yet** - existing form still works

#### Step 3: Add Feature Flag
```ruby
# config/initializers/prompt_tracker.rb
PromptTracker.configure do |config|
  config.use_new_evaluation_ui = ENV.fetch("PT_NEW_EVAL_UI", "false") == "true"
end
```

#### Step 4: Deploy New UI (Behind Flag)
- Deploy type-specific forms
- Deploy evaluator config UI
- **Only visible if flag enabled**

#### Step 5: Test & Validate
- Enable flag for internal testing
- Test all three evaluation types
- Validate auto-evaluation works
- Check backward compatibility

#### Step 6: Gradual Rollout
- Week 1: Enable for 10% of prompts
- Week 2: Enable for 50% of prompts
- Week 3: Enable for 100% of prompts
- Monitor errors and user feedback

#### Step 7: Remove Old Code
- After 2 weeks of 100% rollout
- Remove old generic form
- Remove feature flag
- Update documentation

### Rollback Plan

If issues arise:
1. Set feature flag to `false`
2. Users revert to old generic form
3. Fix issues in new code
4. Re-enable flag when ready

**No data loss** - both systems use same `evaluations` table.

---

## Success Metrics

### Adoption Metrics

**Goal:** Measure how many users adopt the new system

| Metric | Target | Measurement |
|--------|--------|-------------|
| % of prompts with auto-evaluation configured | 30% by Month 3 | `EvaluatorConfig.count / Prompt.count` |
| % of evaluations created via automated evaluators | 60% by Month 3 | `Evaluation.where(evaluator_type: 'automated').count / Evaluation.count` |
| % of evaluations created via LLM judge | 20% by Month 3 | `Evaluation.where(evaluator_type: 'llm_judge').count / Evaluation.count` |
| Number of custom evaluators registered | 5+ by Month 6 | Count evaluators beyond built-in 4 |

### Performance Metrics

**Goal:** Ensure system performs well at scale

| Metric | Target | Measurement |
|--------|--------|-------------|
| Automated evaluation latency (sync) | < 100ms p95 | Monitor `EvaluationService.create_automated` duration |
| LLM judge evaluation latency | < 15s p95 | Monitor `EvaluationJob` duration |
| Auto-evaluation success rate | > 95% | `successful_evals / total_evals` |
| Background job failure rate | < 2% | Monitor `EvaluationJob` failures |

### User Experience Metrics

**Goal:** Improve ease of use and reduce errors

| Metric | Baseline | Target | Measurement |
|--------|----------|--------|-------------|
| Time to create human evaluation | 60s | 30s | User testing |
| Evaluation form errors | 15% | < 5% | Form submission failures |
| User satisfaction (NPS) | N/A | 8+ | Survey after 1 month |
| Support tickets about evaluations | N/A | < 5/month | Ticket tracking |

### Business Impact Metrics

**Goal:** Demonstrate value of automated evaluation

| Metric | Target | Measurement |
|--------|--------|-------------|
| Hours saved per week (vs manual) | 10+ hours | `automated_evals * 30s / 3600` |
| Evaluation coverage (% responses evaluated) | 80%+ | `responses_with_evals / total_responses` |
| Average evaluations per response | 2+ | `Evaluation.count / LlmResponse.count` |
| Quality score improvement | +10% | Compare avg scores before/after |

### Monitoring & Alerts

**Set up alerts for:**
- Auto-evaluation failure rate > 5%
- LLM judge API errors > 10/hour
- Background job queue depth > 100
- Evaluation creation latency > 1s p95

**Dashboard to track:**
- Evaluations created per day (by type)
- Top evaluators by usage
- Average scores by prompt
- Auto-evaluation coverage by prompt

---

## Implementation Timeline

### Week 1: Foundation
- [ ] Create `EvaluatorRegistry` class
- [ ] Create `evaluator_configs` table migration
- [ ] Create `EvaluatorConfig` model
- [ ] Register 4 built-in evaluators
- [ ] Write tests for registry

### Week 2: Auto-Evaluation
- [ ] Create `AutoEvaluationService`
- [ ] Create `EvaluationJob`
- [ ] Add `after_create` callback to `LlmResponse`
- [ ] Write tests for auto-evaluation
- [ ] Deploy to staging

### Week 3: UI - Type Selector & Human Form
- [ ] Create evaluation type selector component
- [ ] Create human evaluation form
- [ ] Add JavaScript for form switching
- [ ] Write integration tests
- [ ] Deploy behind feature flag

### Week 4: UI - Automated & LLM Judge Forms
- [ ] Create automated evaluation form
- [ ] Create LLM judge evaluation form
- [ ] Add live preview for automated evals
- [ ] Add job status indicator for LLM judge
- [ ] Write integration tests

### Week 5: Evaluator Config UI
- [ ] Create `EvaluatorConfigsController`
- [ ] Create evaluator config index view
- [ ] Create evaluator config form
- [ ] Add enable/disable toggle
- [ ] Write integration tests

### Week 6: Testing & Refinement
- [ ] End-to-end testing
- [ ] Performance testing
- [ ] Fix bugs
- [ ] Update documentation
- [ ] Prepare for rollout

### Week 7-8: Gradual Rollout
- [ ] Enable for 10% of users
- [ ] Monitor metrics
- [ ] Enable for 50% of users
- [ ] Enable for 100% of users

### Week 9: Cleanup
- [ ] Remove old code
- [ ] Remove feature flag
- [ ] Final documentation update
- [ ] Celebrate! 🎉

---

## Developer Guide: Creating Custom Evaluators

### Example: Sentiment Evaluator

**Step 1: Create Evaluator Class**
```ruby
# app/services/prompt_tracker/evaluators/sentiment_evaluator.rb
module PromptTracker
  module Evaluators
    class SentimentEvaluator < BaseEvaluator
      def evaluator_id
        "sentiment_check"
      end

      private

      def evaluate_score
        sentiment = analyze_sentiment(llm_response.response_text)

        case sentiment
        when :positive then 100
        when :neutral then 75
        when :negative then 25
        end
      end

      def evaluate_criteria
        sentiment = analyze_sentiment(llm_response.response_text)

        {
          sentiment: sentiment_score(sentiment),
          positivity: positivity_score(llm_response.response_text)
        }
      end

      def generate_feedback
        sentiment = analyze_sentiment(llm_response.response_text)
        "Response sentiment: #{sentiment}"
      end

      def analyze_sentiment(text)
        # Simple keyword-based sentiment analysis
        positive_words = config[:positive_keywords] || %w[great excellent good happy]
        negative_words = config[:negative_keywords] || %w[bad terrible poor sad]

        positive_count = positive_words.count { |word| text.downcase.include?(word) }
        negative_count = negative_words.count { |word| text.downcase.include?(word) }

        if positive_count > negative_count
          :positive
        elsif negative_count > positive_count
          :negative
        else
          :neutral
        end
      end

      def sentiment_score(sentiment)
        case sentiment
        when :positive then 100
        when :neutral then 50
        when :negative then 0
        end
      end

      def positivity_score(text)
        positive_words = config[:positive_keywords] || %w[great excellent good happy]
        count = positive_words.count { |word| text.downcase.include?(word) }
        [count * 25, 100].min
      end
    end
  end
end
```

**Step 2: Register Evaluator**
```ruby
# config/initializers/custom_evaluators.rb
PromptTracker::EvaluatorRegistry.register(
  key: :sentiment_check,
  name: "Sentiment Analyzer",
  description: "Analyzes the sentiment of the response",
  type: :automated,
  class_name: "PromptTracker::Evaluators::SentimentEvaluator",
  config_schema: {
    positive_keywords: {
      type: :array,
      default: %w[great excellent good happy],
      description: "Words indicating positive sentiment"
    },
    negative_keywords: {
      type: :array,
      default: %w[bad terrible poor sad],
      description: "Words indicating negative sentiment"
    }
  },
  icon: "bi-emoji-smile"
)
```

**Step 3: Use in UI or Code**

Via UI:
1. Go to prompt show page
2. Click "Auto-Evaluation" tab
3. Click "+ Add Evaluator"
4. Select "Sentiment Analyzer"
5. Configure keywords
6. Save

Via Code:
```ruby
response = PromptTracker::LlmResponse.last
evaluator = PromptTracker::Evaluators::SentimentEvaluator.new(
  response,
  positive_keywords: %w[amazing fantastic wonderful],
  negative_keywords: %w[awful horrible disappointing]
)
result = evaluator.evaluate

PromptTracker::EvaluationService.create_automated(
  llm_response: response,
  evaluator_id: "sentiment_check",
  score: result.score,
  criteria_scores: result.criteria_scores,
  feedback: result.feedback
)
```

---

## Complete Example: Multi-Evaluator Setup

### Scenario: Customer Support Response Evaluation

**Goal:** Evaluate customer support responses across multiple dimensions with weighted scoring.

**Requirements:**
1. Response must be 50-500 characters (weight: 15%)
2. Must include greeting keywords (weight: 20%)
3. Must have positive sentiment (weight: 35%)
4. Overall quality assessed by GPT-4 (weight: 30%)
5. Skip GPT-4 if basic checks fail (save API costs)

### Step 1: Configure Evaluators for Prompt

```ruby
# In your application or Rails console
prompt = PromptTracker::Prompt.find_by(key: "customer_support_response")

# Set aggregation strategy
prompt.update!(score_aggregation_strategy: "weighted_average")

# Tier 1: Basic validation (sync, fast, no dependencies)
prompt.evaluator_configs.create!(
  evaluator_key: :length_check,
  enabled: true,
  run_mode: "sync",
  priority: 1,
  weight: 0.15,
  config: {
    min_length: 50,
    max_length: 500,
    ideal_min: 100,
    ideal_max: 300
  }
)

prompt.evaluator_configs.create!(
  evaluator_key: :keyword_check,
  enabled: true,
  run_mode: "sync",
  priority: 2,
  weight: 0.20,
  config: {
    required_keywords: ["hello", "hi", "thank you", "help"],
    case_sensitive: false
  }
)

# Tier 2: Content quality (depends on basic checks)
prompt.evaluator_configs.create!(
  evaluator_key: :sentiment_check,
  enabled: true,
  run_mode: "sync",
  priority: 3,
  weight: 0.35,
  depends_on: "length_check",
  min_dependency_score: 80,
  config: {
    positive_keywords: ["great", "happy", "excellent", "wonderful"],
    negative_keywords: ["bad", "terrible", "awful", "horrible"]
  }
)

# Tier 3: AI quality assessment (expensive, only if basics pass)
prompt.evaluator_configs.create!(
  evaluator_key: :gpt4_judge,
  enabled: true,
  run_mode: "async",
  priority: 4,
  weight: 0.30,
  depends_on: "keyword_check",
  min_dependency_score: 90,
  config: {
    judge_model: "gpt-4",
    criteria: ["helpfulness", "professionalism", "clarity"],
    custom_instructions: "Evaluate as if you're a customer support manager.",
    score_min: 0,
    score_max: 100
  }
)
```

### Step 2: Create Response (Auto-Evaluation Triggers)

```ruby
# When you create a response, all evaluators run automatically
response = PromptTracker::LlmCallService.track(
  prompt_key: "customer_support_response",
  variables: { customer_name: "John" },
  model: "gpt-4",
  temperature: 0.7
) do |rendered_prompt|
  # Your LLM API call
  OpenAI.chat(messages: [{ role: "user", content: rendered_prompt }])
end

# Auto-evaluation happens in background via after_create callback
# AutoEvaluationService.evaluate(response) is called automatically
```

### Step 3: View Results

```ruby
# After evaluations complete (sync ones immediate, async after job runs)
response.reload

# Individual evaluation scores
response.evaluations.each do |eval|
  puts "#{eval.evaluator_id}: #{eval.score}/100"
  puts "  Feedback: #{eval.feedback}"
  puts "  Weight: #{eval.metadata['weight']}"
  puts
end

# Output:
# length_check: 95/100
#   Feedback: Response length: 247 characters (ideal: 100-300)
#   Weight: 0.15
#
# keyword_check: 100/100
#   Feedback: All required keywords present: hello, thank you, help
#   Weight: 0.20
#
# sentiment_check: 85/100
#   Feedback: Response sentiment: Positive
#   Weight: 0.35
#
# gpt4_judge: 90/100
#   Feedback: Excellent customer support response. Professional, helpful, and clear.
#   Weight: 0.30

# Overall weighted score
puts "Overall Score: #{response.overall_score}/100"
# Output: Overall Score: 89.75/100
# Calculation: (95*0.15) + (100*0.20) + (85*0.35) + (90*0.30) = 89.75

# Detailed breakdown
response.evaluation_breakdown.each do |eval|
  puts "#{eval[:evaluator_name]}: #{eval[:score]} (weight: #{eval[:normalized_weight]*100}%)"
end

# Check if response passes threshold
if response.passes_threshold?(80)
  puts "✅ Response meets quality standards"
else
  puts "❌ Response needs improvement"
  puts "Weakest area: #{response.weakest_evaluation.evaluator_id}"
end
```

### Step 4: Handle Failed Dependencies

```ruby
# Example: Response that fails keyword check
bad_response = PromptTracker::LlmResponse.create!(
  prompt: prompt,
  rendered_prompt: "What can I help you with?",
  response_text: "I don't know.",  # No greeting keywords!
  model: "gpt-4",
  status: "success"
)

# After auto-evaluation:
bad_response.evaluations.pluck(:evaluator_id, :score)
# => [
#      ["length_check", 95],      # Passed
#      ["keyword_check", 0],       # Failed - no keywords
#      ["sentiment_check", 50]     # Ran (depends on length, which passed)
#      # gpt4_judge NOT present - dependency not met (keyword_check < 90)
#    ]

bad_response.overall_score
# => 48.33  (only 3 evaluations, GPT-4 skipped)

# Check logs:
# "Skipping gpt4_judge - dependency not met (requires keyword_check >= 90)"
```

### Step 5: View in UI

When you navigate to the response page, you'll see:

```
┌─────────────────────────────────────────────────────────┐
│ Overall Score: 89.75/100                     [⭐⭐⭐⭐⭐] │
│ Based on 4 evaluations (weighted average)               │
├─────────────────────────────────────────────────────────┤
│ ✅ Length Validator (15%)        95/100  [█████████▒]  │
│ ✅ Keyword Checker (20%)        100/100  [██████████]  │
│ ✅ Sentiment Analyzer (35%)      85/100  [████████▒▒]  │
│ ✅ GPT-4 Judge (30%)             90/100  [█████████▒]  │
└─────────────────────────────────────────────────────────┘
```

---

## Conclusion

This evaluator system redesign addresses the fundamental UX problem of having a single generic form for all evaluation types. By implementing:

1. **Type-specific forms** - Different UI for human, automated, and LLM judge evaluations
2. **Evaluator registry** - Central discovery and management of evaluators
3. **Auto-evaluation** - Automatic evaluation on response creation
4. **Extensibility** - Easy for developers to create custom evaluators

We create a robust, scalable, and user-friendly evaluation system that supports the full spectrum of evaluation needs in PromptTracker.

**Key Benefits:**
- ✅ **Better UX** - Forms match the evaluation type
- ✅ **Automation** - Reduce manual evaluation burden
- ✅ **Extensibility** - Easy to add custom evaluators
- ✅ **Scalability** - Background jobs for expensive evaluations
- ✅ **Backward Compatible** - Gradual migration path

**Next Steps:**
1. Review this design document
2. Get stakeholder approval
3. Begin Week 1 implementation
4. Iterate based on feedback
