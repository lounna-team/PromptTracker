#!/bin/bash

echo "🧪 Verifying RSpec Setup"
echo "========================"
echo ""

echo "Step 1: Running a single simple test..."
bundle exec rspec spec/models/prompt_tracker/evaluator_config_spec.rb:10 --format documentation

echo ""
echo "Step 2: Running all evaluator_config tests..."
bundle exec rspec spec/models/prompt_tracker/evaluator_config_spec.rb --format progress

echo ""
echo "Step 3: Running all high-priority tests..."
bundle exec rspec \
  spec/models/prompt_tracker/ \
  spec/services/prompt_tracker/ \
  --format progress

echo ""
echo "✅ Verification complete!"

