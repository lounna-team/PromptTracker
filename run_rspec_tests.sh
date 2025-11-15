#!/bin/bash

echo "🧪 Running RSpec Tests for PromptTracker"
echo "========================================"
echo ""

echo "📋 Test Suite Summary:"
echo "  - Model Tests: 1 file (EvaluatorConfig)"
echo "  - Service Tests: 4 files (AutoEvaluation, AbTestCoordinator, AbTestAnalyzer, EvaluatorRegistry)"
echo "  - Total: ~85 tests"
echo ""

echo "🏃 Running all high-priority tests..."
echo ""

bundle exec rspec \
  spec/models/prompt_tracker/evaluator_config_spec.rb \
  spec/services/prompt_tracker/auto_evaluation_service_spec.rb \
  spec/services/prompt_tracker/ab_test_coordinator_spec.rb \
  spec/services/prompt_tracker/ab_test_analyzer_spec.rb \
  spec/services/prompt_tracker/evaluator_registry_spec.rb \
  --format documentation \
  --color

echo ""
echo "✅ Test run complete!"

