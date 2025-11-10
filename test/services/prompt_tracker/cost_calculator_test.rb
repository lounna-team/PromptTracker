# frozen_string_literal: true

require "test_helper"

module PromptTracker
  class CostCalculatorTest < ActiveSupport::TestCase
    # Basic Calculation Tests

    test "should calculate cost for OpenAI GPT-4" do
      calculator = CostCalculator.new("openai", "gpt-4")
      cost = calculator.calculate(tokens_prompt: 100, tokens_completion: 50)

      # Input: (100 / 1000) * 0.03 = 0.003
      # Output: (50 / 1000) * 0.06 = 0.003
      # Total: 0.006
      assert_equal 0.006, cost
    end

    test "should calculate cost for OpenAI GPT-3.5-turbo" do
      calculator = CostCalculator.new("openai", "gpt-3.5-turbo")
      cost = calculator.calculate(tokens_prompt: 1000, tokens_completion: 500)

      # Input: (1000 / 1000) * 0.0015 = 0.0015
      # Output: (500 / 1000) * 0.002 = 0.001
      # Total: 0.0025
      assert_equal 0.0025, cost
    end

    test "should calculate cost for Anthropic Claude-3-Opus" do
      calculator = CostCalculator.new("anthropic", "claude-3-opus")
      cost = calculator.calculate(tokens_prompt: 100, tokens_completion: 50)

      # Input: (100 / 1000) * 0.015 = 0.0015
      # Output: (50 / 1000) * 0.075 = 0.00375
      # Total: 0.00525
      assert_equal 0.00525, cost
    end

    test "should calculate cost for Google Gemini Pro" do
      calculator = CostCalculator.new("google", "gemini-pro")
      cost = calculator.calculate(tokens_prompt: 1000, tokens_completion: 1000)

      # Input: (1000 / 1000) * 0.00025 = 0.00025
      # Output: (1000 / 1000) * 0.0005 = 0.0005
      # Total: 0.00075
      assert_equal 0.00075, cost
    end

    # Fuzzy Model Matching Tests

    test "should match GPT-4 variants to base GPT-4 pricing" do
      variants = ["gpt-4-0125-preview", "gpt-4-turbo-preview", "gpt-4-1106-preview"]

      variants.each do |variant|
        calculator = CostCalculator.new("openai", variant)
        assert calculator.pricing_available?, "Pricing should be available for #{variant}"
      end
    end

    test "should match Claude variants to base pricing" do
      calculator = CostCalculator.new("anthropic", "claude-3-opus-20240229")
      assert calculator.pricing_available?
      assert_equal 0.015, calculator.input_price
    end

    test "should handle exact model matches" do
      calculator = CostCalculator.new("openai", "gpt-4")
      assert calculator.pricing_available?
      assert_equal 0.03, calculator.input_price
      assert_equal 0.06, calculator.output_price
    end

    # Edge Cases

    test "should return 0 for zero tokens" do
      calculator = CostCalculator.new("openai", "gpt-4")
      cost = calculator.calculate(tokens_prompt: 0, tokens_completion: 0)
      assert_equal 0.0, cost
    end

    test "should handle nil tokens" do
      calculator = CostCalculator.new("openai", "gpt-4")
      cost = calculator.calculate(tokens_prompt: nil, tokens_completion: nil)
      assert_equal 0.0, cost
    end

    test "should handle only prompt tokens" do
      calculator = CostCalculator.new("openai", "gpt-4")
      cost = calculator.calculate(tokens_prompt: 100, tokens_completion: 0)
      assert_equal 0.003, cost
    end

    test "should handle only completion tokens" do
      calculator = CostCalculator.new("openai", "gpt-4")
      cost = calculator.calculate(tokens_prompt: 0, tokens_completion: 50)
      assert_equal 0.003, cost
    end

    # Unknown Provider/Model Tests

    test "should return 0 for unknown provider" do
      calculator = CostCalculator.new("unknown_provider", "some-model")
      assert_not calculator.pricing_available?
      cost = calculator.calculate(tokens_prompt: 100, tokens_completion: 50)
      assert_equal 0.0, cost
    end

    test "should return 0 for unknown model" do
      calculator = CostCalculator.new("openai", "unknown-model")
      assert_not calculator.pricing_available?
      cost = calculator.calculate(tokens_prompt: 100, tokens_completion: 50)
      assert_equal 0.0, cost
    end

    test "should return nil pricing for unknown provider" do
      calculator = CostCalculator.new("unknown", "model")
      assert_nil calculator.input_price
      assert_nil calculator.output_price
    end

    # Class Method Tests

    test "should calculate using class method" do
      cost = CostCalculator.calculate(
        provider: "openai",
        model: "gpt-4",
        tokens_prompt: 100,
        tokens_completion: 50
      )
      assert_equal 0.006, cost
    end

    test "should handle class method with zero tokens" do
      cost = CostCalculator.calculate(
        provider: "openai",
        model: "gpt-4",
        tokens_prompt: 0,
        tokens_completion: 0
      )
      assert_equal 0.0, cost
    end

    # Provider/Model Listing Tests

    test "should list available providers" do
      providers = CostCalculator.available_providers
      assert_includes providers, "openai"
      assert_includes providers, "anthropic"
      assert_includes providers, "google"
      assert_includes providers, "cohere"
    end

    test "should list available models for OpenAI" do
      models = CostCalculator.available_models("openai")
      assert_includes models, "gpt-4"
      assert_includes models, "gpt-3.5-turbo"
      assert_includes models, "gpt-4-turbo"
    end

    test "should list available models for Anthropic" do
      models = CostCalculator.available_models("anthropic")
      assert_includes models, "claude-3-opus"
      assert_includes models, "claude-3-sonnet"
      assert_includes models, "claude-3-haiku"
    end

    test "should return empty array for unknown provider" do
      models = CostCalculator.available_models("unknown")
      assert_equal [], models
    end

    # Case Insensitivity Tests

    test "should handle case-insensitive provider names" do
      calculator = CostCalculator.new("OpenAI", "gpt-4")
      assert calculator.pricing_available?
    end

    test "should handle case-insensitive model names" do
      calculator = CostCalculator.new("openai", "GPT-4")
      assert calculator.pricing_available?
    end

    # Pricing Accuracy Tests

    test "should have correct pricing for all OpenAI models" do
      pricing = CostCalculator::PRICING["openai"]
      assert_equal 0.03, pricing["gpt-4"][:input]
      assert_equal 0.06, pricing["gpt-4"][:output]
      assert_equal 0.0015, pricing["gpt-3.5-turbo"][:input]
      assert_equal 0.002, pricing["gpt-3.5-turbo"][:output]
    end

    test "should have correct pricing for all Anthropic models" do
      pricing = CostCalculator::PRICING["anthropic"]
      assert_equal 0.015, pricing["claude-3-opus"][:input]
      assert_equal 0.075, pricing["claude-3-opus"][:output]
      assert_equal 0.003, pricing["claude-3-sonnet"][:input]
      assert_equal 0.015, pricing["claude-3-sonnet"][:output]
    end

    # Large Number Tests

    test "should handle large token counts" do
      calculator = CostCalculator.new("openai", "gpt-4")
      cost = calculator.calculate(tokens_prompt: 100_000, tokens_completion: 50_000)

      # Input: (100000 / 1000) * 0.03 = 3.0
      # Output: (50000 / 1000) * 0.06 = 3.0
      # Total: 6.0
      assert_equal 6.0, cost
    end

    test "should round to 6 decimal places" do
      calculator = CostCalculator.new("openai", "gpt-4")
      cost = calculator.calculate(tokens_prompt: 1, tokens_completion: 1)

      # Should be rounded to 6 decimals
      assert_equal 0.00009, cost
    end

    # Instance Variable Tests

    test "should expose provider and model" do
      calculator = CostCalculator.new("openai", "gpt-4")
      assert_equal "openai", calculator.provider
      assert_equal "gpt-4", calculator.model
    end

    test "should expose pricing hash" do
      calculator = CostCalculator.new("openai", "gpt-4")
      assert_equal({ input: 0.03, output: 0.06 }, calculator.pricing)
    end

    test "should have nil pricing for unknown model" do
      calculator = CostCalculator.new("openai", "unknown")
      assert_nil calculator.pricing
    end
  end
end

