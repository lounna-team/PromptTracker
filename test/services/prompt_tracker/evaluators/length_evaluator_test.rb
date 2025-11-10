# frozen_string_literal: true

require "test_helper"

module PromptTracker
  module Evaluators
    class LengthEvaluatorTest < ActiveSupport::TestCase
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

      test "should score perfect for ideal length" do
        response = create_response("a" * 100) # Within ideal range (50-500)
        evaluator = LengthEvaluator.new(response)

        assert_equal 100, evaluator.evaluate_score
      end

      test "should score low for too short response" do
        response = create_response("hi") # 2 chars, below min (10)
        evaluator = LengthEvaluator.new(response)

        assert_equal 20, evaluator.evaluate_score
      end

      test "should score low for too long response" do
        response = create_response("a" * 3000) # Above max (2000)
        evaluator = LengthEvaluator.new(response)

        assert_equal 30, evaluator.evaluate_score
      end

      test "should score medium for acceptable but not ideal length" do
        response = create_response("a" * 30) # Between min (10) and ideal_min (50)
        evaluator = LengthEvaluator.new(response)

        score = evaluator.evaluate_score
        assert score > 50
        assert score < 100
      end

      test "should use custom config" do
        response = create_response("a" * 20)
        evaluator = LengthEvaluator.new(response, {
          min_length: 10,
          max_length: 100,
          ideal_min: 15,
          ideal_max: 25
        })

        assert_equal 100, evaluator.evaluate_score # Within custom ideal range
      end

      test "should generate appropriate feedback for too short" do
        response = create_response("hi")
        evaluator = LengthEvaluator.new(response)

        feedback = evaluator.generate_feedback
        assert_match(/too short/i, feedback)
        assert_match(/2 chars/, feedback)
      end

      test "should generate appropriate feedback for too long" do
        response = create_response("a" * 3000)
        evaluator = LengthEvaluator.new(response)

        feedback = evaluator.generate_feedback
        assert_match(/too long/i, feedback)
      end

      test "should generate appropriate feedback for ideal length" do
        response = create_response("a" * 100)
        evaluator = LengthEvaluator.new(response)

        feedback = evaluator.generate_feedback
        assert_match(/ideal/i, feedback)
      end

      test "should evaluate criteria scores" do
        response = create_response("a" * 100)
        evaluator = LengthEvaluator.new(response)

        criteria = evaluator.evaluate_criteria
        assert_equal 100, criteria["length"]
        assert_equal 100, criteria["within_min_max"]
        assert_equal 100, criteria["within_ideal"]
      end

      test "should create evaluation record" do
        response = create_response("a" * 100)
        evaluator = LengthEvaluator.new(response)

        evaluation = evaluator.evaluate

        assert evaluation.persisted?
        assert_equal "automated", evaluation.evaluator_type
        assert_equal "length_evaluator_v1", evaluation.evaluator_id
        assert_equal 100, evaluation.score
        assert_equal 0, evaluation.score_min
        assert_equal 100, evaluation.score_max
        assert_not_nil evaluation.feedback
      end

      test "should include metadata" do
        response = create_response("a" * 100)
        evaluator = LengthEvaluator.new(response)

        metadata = evaluator.metadata
        assert_equal 100, metadata[:response_length]
        assert_equal 10, metadata[:min_length]
        assert_equal 2000, metadata[:max_length]
        assert_equal 50, metadata[:ideal_min]
        assert_equal 500, metadata[:ideal_max]
      end

      test "should handle empty response" do
        response = create_response("")
        evaluator = LengthEvaluator.new(response)

        assert_equal 20, evaluator.evaluate_score # Too short
      end

      test "should scale score correctly between min and ideal_min" do
        response1 = create_response("a" * 10) # At min_length
        response2 = create_response("a" * 30) # Between min and ideal_min
        response3 = create_response("a" * 50) # At ideal_min

        evaluator1 = LengthEvaluator.new(response1)
        evaluator2 = LengthEvaluator.new(response2)
        evaluator3 = LengthEvaluator.new(response3)

        score1 = evaluator1.evaluate_score
        score2 = evaluator2.evaluate_score
        score3 = evaluator3.evaluate_score

        assert score1 < score2
        assert score2 < score3
        assert_equal 100, score3
      end
    end
  end
end

