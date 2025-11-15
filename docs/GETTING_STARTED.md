# Getting Started with the Evaluator System

This guide will help you get started with the PromptTracker multi-evaluator system.

## Quick Start

### 1. Run Migrations

```bash
bin/rails db:migrate
```

This creates:
- `evaluator_configs` table for storing evaluator configurations
- `score_aggregation_strategy` column on prompts

### 2. Try the Example

```bash
bin/rails console
load 'examples/multi_evaluator_setup.rb'
```

This will:
- Create a sample prompt with 3 evaluators
- Configure weighted scoring (15%, 30%, 25%, 30%)
- Create a response and trigger auto-evaluation
- Show you the evaluation breakdown

### 3. Explore the Results

```ruby
# Find the response
response = PromptTracker::LlmResponse.last

# View overall score
response.overall_score
# => 87.5

# View detailed breakdown
response.evaluation_breakdown
# => [
#   { evaluator_id: :length_check, score: 95, weight: 0.15, ... },
#   { evaluator_id: :keyword_check, score: 100, weight: 0.30, ... },
#   { evaluator_id: :format_check, score: 85, weight: 0.25, ... }
# ]

# Check if it passes quality threshold
response.passes_threshold?(80)
# => true

# Find weakest area
response.weakest_evaluation.evaluator_id
# => :format_check
```

## Core Concepts

### 1. Evaluator Registry

All available evaluators are registered in `EvaluatorRegistry`:

```ruby
# View all evaluators
PromptTracker::EvaluatorRegistry.all
# => {
#   length_check: { name: "Length Validator", ... },
#   keyword_check: { name: "Keyword Checker", ... },
#   format_check: { name: "Format Validator", ... },
#   gpt4_judge: { name: "GPT-4 Judge", ... }
# }

# Get info about a specific evaluator
PromptTracker::EvaluatorRegistry.get(:length_check)
```

### 2. Configuring Evaluators for a Prompt

```ruby
prompt = PromptTracker::Prompt.find_by(name: "my_prompt")

# Set aggregation strategy
prompt.update!(score_aggregation_strategy: "weighted_average")

# Add an evaluator
prompt.evaluator_configs.create!(
  evaluator_key: :length_check,
  enabled: true,
  run_mode: "sync",      # "sync" or "async"
  priority: 1,           # higher runs first
  weight: 0.20,          # 20% of overall score
  config: {
    min_length: 50,
    max_length: 500,
    ideal_min: 100,
    ideal_max: 300
  }
)
```

### 3. Score Aggregation Strategies

Choose how multiple evaluation scores are combined:

```ruby
# Simple average (all evaluators weighted equally)
prompt.update!(score_aggregation_strategy: "simple_average")

# Weighted average (use config weights) - DEFAULT
prompt.update!(score_aggregation_strategy: "weighted_average")

# Minimum score (all must pass)
prompt.update!(score_aggregation_strategy: "minimum")

# Custom logic (implement in your app)
prompt.update!(score_aggregation_strategy: "custom")
```

### 4. Evaluation Dependencies

Run expensive evaluators only if basic checks pass:

```ruby
# Basic check (runs first)
prompt.evaluator_configs.create!(
  evaluator_key: :keyword_check,
  priority: 1,
  weight: 0.30
)

# Expensive check (only runs if keyword_check >= 80)
prompt.evaluator_configs.create!(
  evaluator_key: :gpt4_judge,
  priority: 2,
  weight: 0.70,
  depends_on: "keyword_check",
  min_dependency_score: 80
)
```

### 5. Auto-Evaluation

Evaluations run automatically when responses are created:

```ruby
# Just create a response normally
response = PromptTracker::LlmResponse.create!(
  prompt_version: version,
  response_text: "Hello, how can I help?",
  # ... other attributes
)

# Evaluations happen automatically via after_create callback
# Sync evaluators run immediately
# Async evaluators are scheduled as background jobs

# View results
response.reload
response.overall_score           # => 87.5
response.evaluations.count       # => 3
```

## Common Use Cases

### Use Case 1: Customer Support Responses

```ruby
prompt = PromptTracker::Prompt.find_by(name: "customer_support")
prompt.update!(score_aggregation_strategy: "weighted_average")

# Length check (15%)
prompt.evaluator_configs.create!(
  evaluator_key: :length_check,
  weight: 0.15,
  run_mode: "sync",
  config: { min_length: 50, max_length: 500 }
)

# Keyword check (20%) - must include greeting
prompt.evaluator_configs.create!(
  evaluator_key: :keyword_check,
  weight: 0.20,
  run_mode: "sync",
  config: { required_keywords: ["hello", "help", "thank"] }
)

# Sentiment check (35%) - must be positive
# (You'd need to create this custom evaluator)
prompt.evaluator_configs.create!(
  evaluator_key: :sentiment_check,
  weight: 0.35,
  run_mode: "sync",
  depends_on: "length_check",
  min_dependency_score: 80
)

# LLM judge (30%) - overall quality
prompt.evaluator_configs.create!(
  evaluator_key: :gpt4_judge,
  weight: 0.30,
  run_mode: "async",
  depends_on: "keyword_check",
  min_dependency_score: 90,
  config: {
    judge_model: "gpt-4",
    criteria: ["helpfulness", "professionalism", "clarity"]
  }
)
```

### Use Case 2: Technical Documentation

```ruby
prompt = PromptTracker::Prompt.find_by(name: "tech_docs")
prompt.update!(score_aggregation_strategy: "minimum") # All must pass

# Format check (must be valid Markdown)
prompt.evaluator_configs.create!(
  evaluator_key: :format_check,
  weight: 1.0,
  run_mode: "sync",
  config: { expected_format: "markdown", strict: true }
)

# Length check (must be detailed)
prompt.evaluator_configs.create!(
  evaluator_key: :length_check,
  weight: 1.0,
  run_mode: "sync",
  config: { min_length: 200, max_length: 2000 }
)

# LLM judge (technical accuracy)
prompt.evaluator_configs.create!(
  evaluator_key: :gpt4_judge,
  weight: 1.0,
  run_mode: "async",
  depends_on: "format_check",
  min_dependency_score: 100,
  config: {
    judge_model: "gpt-4",
    criteria: ["technical_accuracy", "completeness", "clarity"],
    custom_instructions: "Evaluate as a senior technical writer"
  }
)
```

## Creating Custom Evaluators

See `docs/EVALUATOR_SYSTEM_DESIGN.md` for detailed instructions on creating custom evaluators.

Quick example:

```ruby
# app/services/prompt_tracker/evaluators/sentiment_evaluator.rb
module PromptTracker
  module Evaluators
    class SentimentEvaluator < BaseEvaluator
      def evaluate_score
        positive_count = count_keywords(config[:positive_keywords] || [])
        negative_count = count_keywords(config[:negative_keywords] || [])
        
        if negative_count > 0
          50 - (negative_count * 10)
        elsif positive_count >= 2
          100
        elsif positive_count == 1
          80
        else
          60
        end
      end
      
      def evaluator_id
        "sentiment_evaluator_v1"
      end
      
      private
      
      def count_keywords(keywords)
        keywords.count { |kw| response_text.downcase.include?(kw.downcase) }
      end
    end
  end
end

# Register it
PromptTracker::EvaluatorRegistry.register(
  key: :sentiment_check,
  name: "Sentiment Analyzer",
  description: "Analyzes response sentiment",
  evaluator_class: PromptTracker::Evaluators::SentimentEvaluator,
  category: :content,
  config_schema: {
    positive_keywords: { type: :array, default: [] },
    negative_keywords: { type: :array, default: [] }
  }
)
```

## Next Steps

1. **Run the example** to see the system in action
2. **Configure evaluators** for your existing prompts
3. **Create custom evaluators** for your specific needs
4. **Monitor quality** using the evaluation scores
5. **Iterate** on your evaluator configs based on results

## Troubleshooting

### Evaluations not running?

Check:
1. Are evaluator configs enabled? `prompt.evaluator_configs.enabled`
2. Are dependencies met? Check `config.dependency_met?(response)`
3. Check logs for errors: `tail -f log/development.log`

### Scores seem wrong?

Check:
1. Aggregation strategy: `prompt.score_aggregation_strategy`
2. Weights sum to 1.0: `prompt.evaluator_configs.enabled.sum(:weight)`
3. Individual scores: `response.evaluation_breakdown`

### Async evaluations not completing?

Check:
1. Background job processor running? `bin/rails jobs:work`
2. Check job status in logs
3. Verify LLM API credentials (for LLM judge)

## Resources

- **Design Document:** `docs/EVALUATOR_SYSTEM_DESIGN.md`
- **Examples:** `examples/`
- **Implementation Status:** `IMPLEMENTATION_STATUS.md`
- **Code:** `app/services/prompt_tracker/evaluators/`

