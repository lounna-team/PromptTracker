# frozen_string_literal: true

require "test_helper"

module PromptTracker
  module Evaluators
    class KeywordEvaluatorTest < ActiveSupport::TestCase
      setup do
        @prompt = Prompt.create!(
          name: "test_prompt",
          description: "Test",
          category: "test"
        )

        @version = @prompt.prompt_versions.create!(
          template: "Test",
          status: "active",
          source: "api"
        )
      end

      def create_response(text)
        @version.llm_responses.create!(
          rendered_prompt: "Test",
          provider: "openai",
          model: "gpt-4",
          response_text: text,
          status: "success"
        )
      end

      test "should score 100 when all required keywords present" do
        response = create_response("Hello, welcome to our service!")
        evaluator = KeywordEvaluator.new(response, {
          required_keywords: ["hello", "welcome"]
        })

        assert_equal 100, evaluator.evaluate_score
      end

      test "should score 0 when no required keywords present" do
        response = create_response("Goodbye!")
        evaluator = KeywordEvaluator.new(response, {
          required_keywords: ["hello", "welcome"]
        })

        assert_equal 0, evaluator.evaluate_score
      end

      test "should score 100 when no forbidden keywords present" do
        response = create_response("Everything is working great!")
        evaluator = KeywordEvaluator.new(response, {
          forbidden_keywords: ["error", "failed"]
        })

        assert_equal 100, evaluator.evaluate_score
      end

      test "should score 0 when all forbidden keywords present" do
        response = create_response("Error: operation failed")
        evaluator = KeywordEvaluator.new(response, {
          forbidden_keywords: ["error", "failed"]
        })

        assert_equal 0, evaluator.evaluate_score
      end

      test "should handle both required and forbidden keywords" do
        response = create_response("Hello! Everything is working.")
        evaluator = KeywordEvaluator.new(response, {
          required_keywords: ["hello"],
          forbidden_keywords: ["error"]
        })

        assert_equal 100, evaluator.evaluate_score
      end

      test "should be case insensitive by default" do
        response = create_response("HELLO WELCOME")
        evaluator = KeywordEvaluator.new(response, {
          required_keywords: ["hello", "welcome"]
        })

        assert_equal 100, evaluator.evaluate_score
      end

      test "should respect case sensitivity when configured" do
        response = create_response("HELLO welcome")
        evaluator = KeywordEvaluator.new(response, {
          required_keywords: ["hello", "welcome"],
          case_sensitive: true
        })

        score = evaluator.evaluate_score
        assert score < 100 # "hello" not found (case mismatch)
      end

      test "should score 100 when no keywords configured" do
        response = create_response("Any text")
        evaluator = KeywordEvaluator.new(response)

        assert_equal 100, evaluator.evaluate_score
      end

      test "should score partial match correctly" do
        response = create_response("Hello there!")
        evaluator = KeywordEvaluator.new(response, {
          required_keywords: ["hello", "welcome", "goodbye"]
        })

        # 1 out of 3 keywords present = 33%
        score = evaluator.evaluate_score
        assert_equal 33, score
      end

      test "should generate feedback for missing keywords" do
        response = create_response("Goodbye!")
        evaluator = KeywordEvaluator.new(response, {
          required_keywords: ["hello", "welcome"]
        })

        feedback = evaluator.generate_feedback
        assert_match(/missing required keywords/i, feedback)
        assert_match(/hello/i, feedback)
        assert_match(/welcome/i, feedback)
      end

      test "should generate feedback for forbidden keywords" do
        response = create_response("Error occurred")
        evaluator = KeywordEvaluator.new(response, {
          forbidden_keywords: ["error"]
        })

        feedback = evaluator.generate_feedback
        assert_match(/forbidden keywords/i, feedback)
        assert_match(/error/i, feedback)
      end

      test "should generate positive feedback when all requirements met" do
        response = create_response("Hello welcome")
        evaluator = KeywordEvaluator.new(response, {
          required_keywords: ["hello", "welcome"]
        })

        feedback = evaluator.generate_feedback
        assert_match(/all keyword requirements met/i, feedback)
      end

      test "should evaluate criteria for each keyword" do
        response = create_response("Hello there!")
        evaluator = KeywordEvaluator.new(response, {
          required_keywords: ["hello", "welcome"],
          forbidden_keywords: ["error"]
        })

        criteria = evaluator.evaluate_criteria
        assert_equal 100, criteria["required_hello"]
        assert_equal 0, criteria["required_welcome"]
        assert_equal 100, criteria["forbidden_error"]
      end

      test "should create evaluation record" do
        response = create_response("Hello welcome")
        evaluator = KeywordEvaluator.new(response, {
          required_keywords: ["hello", "welcome"]
        })

        evaluation = evaluator.evaluate

        assert evaluation.persisted?
        assert_equal "automated", evaluation.evaluator_type
        assert_equal "keyword_evaluator_v1", evaluation.evaluator_id
        assert_equal 100, evaluation.score
      end

      test "should include metadata" do
        response = create_response("Hello")
        evaluator = KeywordEvaluator.new(response, {
          required_keywords: ["hello"],
          forbidden_keywords: ["error"],
          case_sensitive: false
        })

        metadata = evaluator.metadata
        assert_equal ["hello"], metadata[:required_keywords]
        assert_equal ["error"], metadata[:forbidden_keywords]
        assert_equal false, metadata[:case_sensitive]
      end

      test "should weight required and forbidden keywords correctly" do
        # 100% required present, 100% forbidden present
        response = create_response("Hello error")
        evaluator = KeywordEvaluator.new(response, {
          required_keywords: ["hello"],
          forbidden_keywords: ["error"]
        })

        # 70% weight on required (100), 30% on avoiding forbidden (0)
        # = 70 + 0 = 70
        assert_equal 70, evaluator.evaluate_score
      end
    end
  end
end

