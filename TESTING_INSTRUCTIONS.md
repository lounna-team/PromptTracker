# Testing Instructions

## ✅ Migrations Complete!

The migrations have been successfully run:
- ✅ `evaluator_configs` table created
- ✅ `score_aggregation_strategy` column added to prompts

## 🧪 Quick Test

Run this simple test to verify everything works:

```bash
bin/rails console
load 'examples/quick_test.rb'
```

**Expected output:**
```
🧪 Quick Evaluator System Test

Cleaning up test data...
Creating test prompt...
Creating prompt version...
Configuring length evaluator...
✅ Setup complete!

Creating response (auto-evaluation should trigger)...
✅ Response created: ID 1

📊 Results:
  Evaluations count: 1
  ✅ Auto-evaluation worked!
  Overall score: 95.0/100
  
  Evaluation:
    Evaluator: length_evaluator_v1
    Type: automated
    Score: 95/100
    Feedback: Response length is within ideal range

✅ Test complete!
```

## 🚀 Full Example

Once the quick test passes, run the full multi-evaluator example:

```bash
bin/rails console
load 'examples/multi_evaluator_setup.rb'
```

This will:
1. Create a customer support prompt
2. Configure 3 evaluators with weights (15%, 30%, 25%)
3. Set up evaluation dependencies
4. Create a response and trigger auto-evaluation
5. Show detailed evaluation breakdown

## 🔍 Manual Testing

You can also test manually in the console:

```ruby
# 1. Create a prompt
prompt = PromptTracker::Prompt.create!(
  name: "my_test",
  description: "Test prompt",
  score_aggregation_strategy: "weighted_average"
)

# 2. Create a version
version = prompt.prompt_versions.create!(
  template: "Hello {{name}}",
  version_number: 1,
  status: "active",
  source: "api"
)

# 3. Configure an evaluator
prompt.evaluator_configs.create!(
  evaluator_key: :length_check,
  enabled: true,
  run_mode: "sync",
  weight: 1.0,
  config: { min_length: 10, max_length: 100 }
)

# 4. Create a response (auto-evaluation triggers)
response = PromptTracker::LlmResponse.create!(
  prompt_version: version,
  rendered_prompt: "Hello World",
  response_text: "Hello! This is a test response.",
  provider: "openai",
  model: "gpt-4",
  status: "success",
  response_time_ms: 500,
  tokens_total: 10,
  cost_usd: 0.0001
)

# 5. Check results
response.reload
response.overall_score           # Should return a score
response.evaluations.count       # Should be > 0
response.evaluation_breakdown    # Detailed breakdown
```

## 🐛 Troubleshooting

### Issue: No evaluations created

**Check:**
1. Is the evaluator config enabled?
   ```ruby
   prompt.evaluator_configs.enabled
   ```

2. Check the logs for errors:
   ```bash
   tail -f log/development.log
   ```

3. Verify the evaluator exists in registry:
   ```ruby
   PromptTracker::EvaluatorRegistry.all.keys
   # Should include :length_check, :keyword_check, etc.
   ```

### Issue: "Evaluator not found in registry"

**Solution:** Make sure the evaluator is registered. Check:
```ruby
PromptTracker::EvaluatorRegistry.get(:length_check)
```

If it returns `nil`, the evaluator isn't registered. This shouldn't happen with built-in evaluators.

### Issue: Dependency not met

**Check:**
```ruby
config = prompt.evaluator_configs.find_by(evaluator_key: :gpt4_judge)
config.dependency_met?(response)
```

This will tell you if the dependency evaluation exists and meets the minimum score.

### Issue: Circular dependency error

**Solution:** Make sure your dependencies don't form a loop:
```
❌ BAD:
  evaluator_a depends_on: evaluator_b
  evaluator_b depends_on: evaluator_a

✅ GOOD:
  evaluator_a (no dependency)
  evaluator_b depends_on: evaluator_a
  evaluator_c depends_on: evaluator_b
```

## ✅ What to Verify

After running the tests, verify:

1. **Auto-evaluation works**
   - Evaluations are created automatically when responses are created
   - Check: `response.evaluations.count > 0`

2. **Score aggregation works**
   - Overall score is calculated correctly
   - Check: `response.overall_score` returns a number

3. **Weighted scoring works**
   - Scores are weighted according to config
   - Check: `response.evaluation_breakdown` shows weights

4. **Dependencies work**
   - Dependent evaluators only run if dependency is met
   - Test by creating a config with `depends_on` and low `min_dependency_score`

5. **Registry works**
   - All evaluators are discoverable
   - Check: `PromptTracker::EvaluatorRegistry.all`

## 📝 Next Steps

Once testing is complete:

1. ✅ Verify all tests pass
2. 🎨 Start building UI components (Phase 3)
3. 🧪 Write automated tests (Phase 4)
4. 📚 Update documentation with any findings

## 🎯 Success Criteria

- [x] Migrations run successfully
- [ ] Quick test passes
- [ ] Full example runs without errors
- [ ] Auto-evaluation creates evaluations
- [ ] Overall score is calculated correctly
- [ ] Evaluation breakdown shows all evaluations
- [ ] Dependencies work as expected

Mark each item as you verify it!

