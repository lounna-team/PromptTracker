# frozen_string_literal: true

require "test_helper"

module PromptTracker
  module Evaluators
    class LlmJudgeEvaluatorTest < ActiveSupport::TestCase
      setup do
        @prompt = Prompt.create!(
          name: "test_prompt",
          description: "Test",
          category: "test"
        )

        @version = @prompt.prompt_versions.create!(
          template: "What is {{topic}}?",
          variables_schema: [{ "name" => "topic", "type" => "string", "required" => true }],
          status: "active",
          source: "api"
        )

        @llm_response = @version.llm_responses.create!(
          rendered_prompt: "What is Ruby?",
          variables_used: { topic: "Ruby" },
          provider: "openai",
          model: "gpt-4",
          response_text: "Ruby is a dynamic, object-oriented programming language.",
          status: "success"
        )
      end

      test "should require block to evaluate" do
        evaluator = LlmJudgeEvaluator.new(@llm_response, { judge_model: "gpt-4" })

        assert_raises(ArgumentError) do
          evaluator.evaluate
        end
      end

      test "should build judge prompt with criteria" do
        evaluator = LlmJudgeEvaluator.new(@llm_response, {
          judge_model: "gpt-4",
          criteria: ["accuracy", "helpfulness"]
        })

        # Access private method for testing
        judge_prompt = evaluator.send(:build_judge_prompt)

        assert_match(/What is Ruby\?/, judge_prompt)
        assert_match(/Ruby is a dynamic/, judge_prompt)
        assert_match(/accuracy/i, judge_prompt)
        assert_match(/helpfulness/i, judge_prompt)
      end

      test "should include custom instructions in prompt" do
        evaluator = LlmJudgeEvaluator.new(@llm_response, {
          judge_model: "gpt-4",
          custom_instructions: "Focus on technical accuracy"
        })

        judge_prompt = evaluator.send(:build_judge_prompt)
        assert_match(/Focus on technical accuracy/, judge_prompt)
      end

      test "should parse judge response with structured format" do
        judge_response = <<~RESPONSE
          OVERALL SCORE: 4.5

          CRITERIA SCORES:
          accuracy: 5.0
          helpfulness: 4.0

          FEEDBACK:
          The response is accurate and helpful.
        RESPONSE

        evaluator = LlmJudgeEvaluator.new(@llm_response, {
          judge_model: "gpt-4",
          criteria: ["accuracy", "helpfulness"]
        })

        evaluation = evaluator.evaluate { judge_response }

        assert evaluation.persisted?
        assert_equal 4.5, evaluation.score
        assert_equal 5.0, evaluation.criteria_scores["accuracy"]
        assert_equal 4.0, evaluation.criteria_scores["helpfulness"]
        assert_match(/accurate and helpful/, evaluation.feedback)
      end

      test "should parse judge response from OpenAI format" do
        judge_response = {
          "choices" => [{
            "message" => {
              "content" => "OVERALL SCORE: 4.0\n\nCRITERIA SCORES:\naccuracy: 4.0\n\nFEEDBACK:\nGood response"
            }
          }]
        }

        evaluator = LlmJudgeEvaluator.new(@llm_response, {
          judge_model: "gpt-4",
          criteria: ["accuracy"]
        })

        evaluation = evaluator.evaluate { judge_response }

        assert_equal 4.0, evaluation.score
        assert_equal 4.0, evaluation.criteria_scores["accuracy"]
      end

      test "should parse judge response from Anthropic format" do
        judge_response = {
          "content" => [{
            "text" => "OVERALL SCORE: 3.5\n\nCRITERIA SCORES:\ntone: 3.5\n\nFEEDBACK:\nNice tone"
          }]
        }

        evaluator = LlmJudgeEvaluator.new(@llm_response, {
          judge_model: "claude-3-opus",
          criteria: ["tone"]
        })

        evaluation = evaluator.evaluate { judge_response }

        assert_equal 3.5, evaluation.score
        assert_equal 3.5, evaluation.criteria_scores["tone"]
      end

      test "should fallback to average of criteria if no overall score" do
        judge_response = <<~RESPONSE
          CRITERIA SCORES:
          accuracy: 4.0
          helpfulness: 5.0

          FEEDBACK:
          Good response
        RESPONSE

        evaluator = LlmJudgeEvaluator.new(@llm_response, {
          judge_model: "gpt-4",
          criteria: ["accuracy", "helpfulness"]
        })

        evaluation = evaluator.evaluate { judge_response }

        # Average of 4.0 and 5.0 = 4.5
        assert_equal 4.5, evaluation.score
      end

      test "should use default score for missing criteria" do
        judge_response = <<~RESPONSE
          OVERALL SCORE: 4.0

          CRITERIA SCORES:
          accuracy: 5.0

          FEEDBACK:
          Good
        RESPONSE

        evaluator = LlmJudgeEvaluator.new(@llm_response, {
          judge_model: "gpt-4",
          criteria: ["accuracy", "helpfulness", "tone"],
          score_max: 5
        })

        evaluation = evaluator.evaluate { judge_response }

        assert_equal 5.0, evaluation.criteria_scores["accuracy"]
        assert_equal 2.5, evaluation.criteria_scores["helpfulness"] # Default: score_max / 2
        assert_equal 2.5, evaluation.criteria_scores["tone"]
      end

      test "should create evaluation with correct attributes" do
        judge_response = "OVERALL SCORE: 4.5\n\nFEEDBACK: Great!"

        evaluator = LlmJudgeEvaluator.new(@llm_response, {
          judge_model: "gpt-4",
          criteria: ["accuracy"]
        })

        evaluation = evaluator.evaluate { judge_response }

        assert_equal "llm_judge", evaluation.evaluator_type
        assert_equal "llm_judge:gpt-4", evaluation.evaluator_id
        assert_equal 0, evaluation.score_min
        assert_equal 5, evaluation.score_max
        assert_equal "gpt-4", evaluation.metadata["judge_model"]
        assert_equal ["accuracy"], evaluation.metadata["criteria"]
      end

      test "should store judge prompt and response in metadata" do
        judge_response = "OVERALL SCORE: 4.0\n\nFEEDBACK: Good"

        evaluator = LlmJudgeEvaluator.new(@llm_response, {
          judge_model: "gpt-4",
          criteria: ["accuracy"]
        })

        evaluation = evaluator.evaluate { judge_response }

        assert_not_nil evaluation.metadata["judge_prompt"]
        assert_match(/What is Ruby/, evaluation.metadata["judge_prompt"])
        assert_equal judge_response, evaluation.metadata["raw_judge_response"]
      end

      test "should use custom score range" do
        judge_response = "OVERALL SCORE: 85\n\nFEEDBACK: Good"

        evaluator = LlmJudgeEvaluator.new(@llm_response, {
          judge_model: "gpt-4",
          criteria: ["accuracy"],
          score_min: 0,
          score_max: 100
        })

        evaluation = evaluator.evaluate { judge_response }

        assert_equal 85, evaluation.score
        assert_equal 0, evaluation.score_min
        assert_equal 100, evaluation.score_max
      end

      test "should handle different judge models" do
        judge_response = "OVERALL SCORE: 4.0\n\nFEEDBACK: Good"

        evaluator = LlmJudgeEvaluator.new(@llm_response, {
          judge_model: "claude-3-sonnet",
          criteria: ["accuracy"]
        })

        evaluation = evaluator.evaluate { judge_response }

        assert_equal "llm_judge:claude-3-sonnet", evaluation.evaluator_id
        assert_equal "claude-3-sonnet", evaluation.metadata["judge_model"]
      end

      test "should handle plain string response" do
        judge_response = "OVERALL SCORE: 4.0\n\nFEEDBACK: Good"

        evaluator = LlmJudgeEvaluator.new(@llm_response, {
          judge_model: "gpt-4",
          criteria: ["accuracy"]
        })

        evaluation = evaluator.evaluate { judge_response }

        assert evaluation.persisted?
        assert_equal 4.0, evaluation.score
      end

      test "should extract feedback from response" do
        judge_response = <<~RESPONSE
          OVERALL SCORE: 4.0

          FEEDBACK:
          This is detailed feedback
          spanning multiple lines.
        RESPONSE

        evaluator = LlmJudgeEvaluator.new(@llm_response, {
          judge_model: "gpt-4",
          criteria: ["accuracy"]
        })

        evaluation = evaluator.evaluate { judge_response }

        assert_match(/detailed feedback/, evaluation.feedback)
        assert_match(/multiple lines/, evaluation.feedback)
      end
    end
  end
end

