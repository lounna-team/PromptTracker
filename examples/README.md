# PromptTracker Examples

This directory contains example scripts demonstrating how to use the PromptTracker evaluator system.

## Running Examples

All examples are designed to be run in the Rails console:

```bash
# Start Rails console
bin/rails console

# Load and run an example
load 'examples/multi_evaluator_setup.rb'
```

## Available Examples

### 1. Multi-Evaluator Setup (`multi_evaluator_setup.rb`)

Demonstrates the complete multi-evaluator system:

- Creating a prompt with multiple evaluator configs
- Setting up weighted scoring (15%, 30%, 25%, 30%)
- Configuring evaluation dependencies
- Auto-evaluation when responses are created
- Viewing evaluation breakdown and overall scores

**What it shows:**
- ✅ Automatic evaluation on response creation
- ✅ Multiple evaluators per response
- ✅ Weighted score aggregation
- ✅ Dependency-based evaluation (skip expensive evaluators if basic checks fail)
- ✅ Sync vs async execution modes

**Run it:**
```ruby
load 'examples/multi_evaluator_setup.rb'
```

## Key Concepts Demonstrated

### 1. Evaluator Registry

All available evaluators are registered in `EvaluatorRegistry`:

```ruby
# View all available evaluators
PromptTracker::EvaluatorRegistry.all

# Get metadata for a specific evaluator
PromptTracker::EvaluatorRegistry.get(:length_check)

# Build an evaluator instance
evaluator = PromptTracker::EvaluatorRegistry.build(:length_check, response, config)
```

### 2. Evaluator Configuration

Configure which evaluators run for each prompt:

```ruby
prompt.evaluator_configs.create!(
  evaluator_key: :length_check,
  enabled: true,
  run_mode: "sync",        # or "async"
  priority: 1,             # higher runs first
  weight: 0.15,            # 15% of overall score
  depends_on: nil,         # no dependency
  min_dependency_score: nil,
  config: {
    min_length: 50,
    max_length: 500
  }
)
```

### 3. Score Aggregation Strategies

Choose how to combine multiple evaluation scores:

```ruby
# Set aggregation strategy on prompt
prompt.update!(score_aggregation_strategy: "weighted_average")

# Available strategies:
# - "simple_average"    - Equal weight for all evaluators
# - "weighted_average"  - Use config weights (default)
# - "minimum"           - Take lowest score (all must pass)
# - "custom"            - Implement your own logic
```

### 4. Evaluation Dependencies

Run expensive evaluators only if basic checks pass:

```ruby
# Only run GPT-4 judge if keyword check scores >= 80
prompt.evaluator_configs.create!(
  evaluator_key: :gpt4_judge,
  depends_on: "keyword_check",
  min_dependency_score: 80,
  # ... other config
)
```

### 5. Auto-Evaluation

Evaluations run automatically when responses are created:

```ruby
# Create a response
response = PromptTracker::LlmResponse.create!(
  prompt_version: version,
  response_text: "Hello!",
  # ... other attributes
)

# Auto-evaluation happens via after_create callback
# AutoEvaluationService.evaluate(response) is called automatically

# View results
response.overall_score           # => 87.5
response.evaluation_breakdown    # => [{ evaluator_id: :length_check, score: 95, ... }, ...]
response.passes_threshold?(80)   # => true
```

## Next Steps

After running the examples:

1. **Explore the UI** - Navigate to `/prompt_tracker` to see the web interface
2. **Create custom evaluators** - Extend `BaseEvaluator` to add your own logic
3. **Configure your prompts** - Set up evaluator configs for your production prompts
4. **Monitor quality** - Use the analytics dashboard to track evaluation scores over time

## Need Help?

- Check the main documentation: `docs/EVALUATOR_SYSTEM_DESIGN.md`
- View the code: `app/services/prompt_tracker/evaluators/`
- Run tests: `bin/rails test`

