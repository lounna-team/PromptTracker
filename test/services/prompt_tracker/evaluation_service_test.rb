# frozen_string_literal: true

require "test_helper"

module PromptTracker
  class EvaluationServiceTest < ActiveSupport::TestCase
    setup do
      @prompt = Prompt.create!(
        name: "test_prompt",
        description: "Test prompt",
        category: "test"
      )

      @version = @prompt.prompt_versions.create!(
        template: "Hello {{name}}!",
        variables_schema: [{ "name" => "name", "type" => "string", "required" => true }],
        status: "active",
        source: "api"
      )

      @llm_response = @version.llm_responses.create!(
        rendered_prompt: "Hello John!",
        variables_used: { name: "John" },
        provider: "openai",
        model: "gpt-4",
        response_text: "Hi there! How can I help you today?",
        status: "success",
        response_time_ms: 1200,
        tokens_total: 20,
        cost_usd: 0.0005
      )
    end

    # Human evaluations

    test "should create human evaluation with valid attributes" do
      evaluation = EvaluationService.create_human(
        llm_response: @llm_response,
        score: 4.5,
        evaluator_id: "john@example.com",
        criteria_scores: { "helpfulness" => 5, "tone" => 4 },
        feedback: "Great response!"
      )

      assert evaluation.persisted?
      assert_equal "human", evaluation.evaluator_type
      assert_equal "john@example.com", evaluation.evaluator_id
      assert_equal 4.5, evaluation.score
      assert_equal 0, evaluation.score_min
      assert_equal 5, evaluation.score_max
      assert_equal({ "helpfulness" => 5, "tone" => 4 }, evaluation.criteria_scores)
      assert_equal "Great response!", evaluation.feedback
    end

    test "should create human evaluation with custom score range" do
      evaluation = EvaluationService.create_human(
        llm_response: @llm_response,
        score: 85,
        evaluator_id: "jane@example.com",
        score_min: 0,
        score_max: 100
      )

      assert_equal 85, evaluation.score
      assert_equal 0, evaluation.score_min
      assert_equal 100, evaluation.score_max
    end

    test "should create human evaluation without optional fields" do
      evaluation = EvaluationService.create_human(
        llm_response: @llm_response,
        score: 4.0,
        evaluator_id: "test@example.com"
      )

      assert evaluation.persisted?
      assert_equal({}, evaluation.criteria_scores)
      assert_nil evaluation.feedback
      assert_equal({}, evaluation.metadata)
    end

    test "should raise error for human evaluation with invalid score" do
      assert_raises(EvaluationService::InvalidScoreError) do
        EvaluationService.create_human(
          llm_response: @llm_response,
          score: 10,
          evaluator_id: "test@example.com",
          score_max: 5
        )
      end
    end

    test "should raise error for human evaluation with missing response" do
      assert_raises(EvaluationService::MissingResponseError) do
        EvaluationService.create_human(
          llm_response: nil,
          score: 4.0,
          evaluator_id: "test@example.com"
        )
      end
    end

    # Automated evaluations

    test "should create automated evaluation with valid attributes" do
      evaluation = EvaluationService.create_automated(
        llm_response: @llm_response,
        evaluator_id: "length_validator_v1",
        score: 85,
        score_max: 100,
        metadata: { length: 42 }
      )

      assert evaluation.persisted?
      assert_equal "automated", evaluation.evaluator_type
      assert_equal "length_validator_v1", evaluation.evaluator_id
      assert_equal 85, evaluation.score
      assert_equal 0, evaluation.score_min
      assert_equal 100, evaluation.score_max
      assert_equal({ "length" => 42 }, evaluation.metadata)
    end

    test "should create automated evaluation with criteria scores" do
      evaluation = EvaluationService.create_automated(
        llm_response: @llm_response,
        evaluator_id: "keyword_checker_v1",
        score: 90,
        criteria_scores: { "has_greeting" => 100, "has_signature" => 80 }
      )

      assert_equal({ "has_greeting" => 100, "has_signature" => 80 }, evaluation.criteria_scores)
    end

    test "should raise error for automated evaluation with invalid score" do
      assert_raises(EvaluationService::InvalidScoreError) do
        EvaluationService.create_automated(
          llm_response: @llm_response,
          evaluator_id: "test_evaluator",
          score: 150,
          score_max: 100
        )
      end
    end

    # LLM judge evaluations

    test "should create LLM judge evaluation with valid attributes" do
      evaluation = EvaluationService.create_llm_judge(
        llm_response: @llm_response,
        judge_model: "gpt-4",
        score: 4.2,
        criteria_scores: { "accuracy" => 4.5, "helpfulness" => 4.0 },
        feedback: "The response is accurate and helpful"
      )

      assert evaluation.persisted?
      assert_equal "llm_judge", evaluation.evaluator_type
      assert_equal "llm_judge:gpt-4", evaluation.evaluator_id
      assert_equal 4.2, evaluation.score
      assert_equal({ "accuracy" => 4.5, "helpfulness" => 4.0 }, evaluation.criteria_scores)
      assert_equal "The response is accurate and helpful", evaluation.feedback
      assert_equal "gpt-4", evaluation.metadata["judge_model"]
    end

    test "should create LLM judge evaluation with different judge models" do
      evaluation = EvaluationService.create_llm_judge(
        llm_response: @llm_response,
        judge_model: "claude-3-opus",
        score: 4.5
      )

      assert_equal "llm_judge:claude-3-opus", evaluation.evaluator_id
      assert_equal "claude-3-opus", evaluation.metadata["judge_model"]
    end

    test "should raise error for LLM judge evaluation with invalid score" do
      assert_raises(EvaluationService::InvalidScoreError) do
        EvaluationService.create_llm_judge(
          llm_response: @llm_response,
          judge_model: "gpt-4",
          score: 6,
          score_max: 5
        )
      end
    end

    # Edge cases

    test "should allow score at minimum boundary" do
      evaluation = EvaluationService.create_human(
        llm_response: @llm_response,
        score: 0,
        evaluator_id: "test@example.com",
        score_min: 0,
        score_max: 5
      )

      assert_equal 0, evaluation.score
    end

    test "should allow score at maximum boundary" do
      evaluation = EvaluationService.create_human(
        llm_response: @llm_response,
        score: 5,
        evaluator_id: "test@example.com",
        score_min: 0,
        score_max: 5
      )

      assert_equal 5, evaluation.score
    end

    test "should handle negative score ranges" do
      evaluation = EvaluationService.create_automated(
        llm_response: @llm_response,
        evaluator_id: "sentiment_analyzer",
        score: -0.5,
        score_min: -1,
        score_max: 1
      )

      assert_equal(-0.5, evaluation.score)
      assert_equal(-1, evaluation.score_min)
      assert_equal 1, evaluation.score_max
    end

    test "should associate evaluation with llm_response" do
      evaluation = EvaluationService.create_human(
        llm_response: @llm_response,
        score: 4.0,
        evaluator_id: "test@example.com"
      )

      assert_equal @llm_response, evaluation.llm_response
      assert_includes @llm_response.evaluations, evaluation
    end

    test "should associate evaluation with prompt_version through llm_response" do
      evaluation = EvaluationService.create_human(
        llm_response: @llm_response,
        score: 4.0,
        evaluator_id: "test@example.com"
      )

      assert_equal @version, evaluation.prompt_version
    end
  end
end

