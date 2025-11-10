# frozen_string_literal: true

require "test_helper"

module PromptTracker
  class EvaluationHelpersTest < ActiveSupport::TestCase
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

      @response = @version.llm_responses.create!(
        rendered_prompt: "Test",
        provider: "openai",
        model: "gpt-4",
        response_text: "Test response",
        status: "success"
      )
    end

    # normalize_score tests

    test "should normalize score from 0-100 to 0-5" do
      result = EvaluationHelpers.normalize_score(85, min: 0, max: 100, target_max: 5)
      assert_equal 4.25, result
    end

    test "should normalize score from 0-5 to 0-1" do
      result = EvaluationHelpers.normalize_score(4.5, min: 0, max: 5, target_max: 1)
      assert_equal 0.9, result
    end

    test "should normalize score with custom target range" do
      result = EvaluationHelpers.normalize_score(50, min: 0, max: 100, target_min: 1, target_max: 10)
      assert_equal 5.5, result
    end

    test "should clamp score at minimum" do
      result = EvaluationHelpers.normalize_score(-10, min: 0, max: 100, target_max: 1)
      assert_equal 0, result
    end

    test "should clamp score at maximum" do
      result = EvaluationHelpers.normalize_score(150, min: 0, max: 100, target_max: 1)
      assert_equal 1, result
    end

    # average_score_for_version tests

    test "should calculate average score for version" do
      @response.evaluations.create!(
        evaluator_type: "human",
        evaluator_id: "user1",
        score: 4.0,
        score_min: 0,
        score_max: 5
      )

      @response.evaluations.create!(
        evaluator_type: "human",
        evaluator_id: "user2",
        score: 5.0,
        score_min: 0,
        score_max: 5
      )

      avg = EvaluationHelpers.average_score_for_version(@version)
      assert_equal 0.9, avg # (0.8 + 1.0) / 2 = 0.9
    end

    test "should normalize scores before averaging" do
      @response.evaluations.create!(
        evaluator_type: "human",
        evaluator_id: "user1",
        score: 80,
        score_min: 0,
        score_max: 100
      )

      @response.evaluations.create!(
        evaluator_type: "automated",
        evaluator_id: "auto1",
        score: 4.0,
        score_min: 0,
        score_max: 5
      )

      avg = EvaluationHelpers.average_score_for_version(@version)
      assert_equal 0.8, avg # (0.8 + 0.8) / 2 = 0.8
    end

    test "should filter by evaluator type" do
      @response.evaluations.create!(
        evaluator_type: "human",
        evaluator_id: "user1",
        score: 5.0,
        score_min: 0,
        score_max: 5
      )

      @response.evaluations.create!(
        evaluator_type: "automated",
        evaluator_id: "auto1",
        score: 50,
        score_min: 0,
        score_max: 100
      )

      avg_human = EvaluationHelpers.average_score_for_version(@version, evaluator_type: "human")
      assert_equal 1.0, avg_human

      avg_auto = EvaluationHelpers.average_score_for_version(@version, evaluator_type: "automated")
      assert_equal 0.5, avg_auto
    end

    test "should return nil when no evaluations" do
      avg = EvaluationHelpers.average_score_for_version(@version)
      assert_nil avg
    end

    # average_score_for_response tests

    test "should calculate average score for response" do
      @response.evaluations.create!(
        evaluator_type: "human",
        evaluator_id: "user1",
        score: 4.0,
        score_min: 0,
        score_max: 5
      )

      avg = EvaluationHelpers.average_score_for_response(@response)
      assert_equal 0.8, avg
    end

    # evaluation_statistics tests

    test "should calculate statistics for evaluations" do
      @response.evaluations.create!(evaluator_type: "human", evaluator_id: "u1", score: 3.0, score_min: 0, score_max: 5)
      @response.evaluations.create!(evaluator_type: "human", evaluator_id: "u2", score: 4.0, score_min: 0, score_max: 5)
      @response.evaluations.create!(evaluator_type: "human", evaluator_id: "u3", score: 5.0, score_min: 0, score_max: 5)

      stats = EvaluationHelpers.evaluation_statistics(@response.evaluations)

      assert_equal 3, stats[:count]
      assert_equal 0.6, stats[:min]
      assert_equal 1.0, stats[:max]
      assert_equal 0.8, stats[:avg]
      assert_equal 0.8, stats[:median]
    end

    test "should calculate median for even number of evaluations" do
      @response.evaluations.create!(evaluator_type: "human", evaluator_id: "u1", score: 2.0, score_min: 0, score_max: 5)
      @response.evaluations.create!(evaluator_type: "human", evaluator_id: "u2", score: 3.0, score_min: 0, score_max: 5)
      @response.evaluations.create!(evaluator_type: "human", evaluator_id: "u3", score: 4.0, score_min: 0, score_max: 5)
      @response.evaluations.create!(evaluator_type: "human", evaluator_id: "u4", score: 5.0, score_min: 0, score_max: 5)

      stats = EvaluationHelpers.evaluation_statistics(@response.evaluations)

      # Median of [0.4, 0.6, 0.8, 1.0] = (0.6 + 0.8) / 2 = 0.7
      assert_equal 0.7, stats[:median]
    end

    test "should return nil for empty evaluations" do
      stats = EvaluationHelpers.evaluation_statistics(Evaluation.none)
      assert_nil stats
    end

    # compare_versions tests

    test "should compare scores across versions" do
      version2 = @prompt.prompt_versions.create!(template: "Test 2", status: "deprecated", source: "api")
      response2 = version2.llm_responses.create!(
        rendered_prompt: "Test",
        provider: "openai",
        model: "gpt-4",
        response_text: "Test",
        status: "success"
      )

      @response.evaluations.create!(evaluator_type: "human", evaluator_id: "u1", score: 4.0, score_min: 0, score_max: 5)
      response2.evaluations.create!(evaluator_type: "human", evaluator_id: "u1", score: 5.0, score_min: 0, score_max: 5)

      comparison = EvaluationHelpers.compare_versions([@version, version2])

      assert_equal 0.8, comparison[@version.version_number]
      assert_equal 1.0, comparison[version2.version_number]
    end

    # best_version tests

    test "should find best performing version" do
      version2 = @prompt.prompt_versions.create!(template: "Test 2", status: "deprecated", source: "api")
      version3 = @prompt.prompt_versions.create!(template: "Test 3", status: "draft", source: "api")

      response2 = version2.llm_responses.create!(
        rendered_prompt: "Test",
        provider: "openai",
        model: "gpt-4",
        response_text: "Test",
        status: "success"
      )

      response3 = version3.llm_responses.create!(
        rendered_prompt: "Test",
        provider: "openai",
        model: "gpt-4",
        response_text: "Test",
        status: "success"
      )

      @response.evaluations.create!(evaluator_type: "human", evaluator_id: "u1", score: 3.0, score_min: 0, score_max: 5)
      response2.evaluations.create!(evaluator_type: "human", evaluator_id: "u1", score: 5.0, score_min: 0, score_max: 5)
      response3.evaluations.create!(evaluator_type: "human", evaluator_id: "u1", score: 4.0, score_min: 0, score_max: 5)

      best = EvaluationHelpers.best_version([@version, version2, version3])

      assert_equal version2, best
    end

    test "should return nil when no evaluations for best_version" do
      version2 = @prompt.prompt_versions.create!(template: "Test 2", status: "deprecated", source: "api")

      best = EvaluationHelpers.best_version([@version, version2])
      assert_nil best
    end

    # aggregate_criteria_scores tests

    test "should aggregate criteria scores" do
      @response.evaluations.create!(
        evaluator_type: "human",
        evaluator_id: "u1",
        score: 4.0,
        score_min: 0,
        score_max: 5,
        criteria_scores: { "accuracy" => 4.0, "tone" => 5.0 }
      )

      @response.evaluations.create!(
        evaluator_type: "human",
        evaluator_id: "u2",
        score: 5.0,
        score_min: 0,
        score_max: 5,
        criteria_scores: { "accuracy" => 5.0, "tone" => 4.0 }
      )

      aggregated = EvaluationHelpers.aggregate_criteria_scores(@response.evaluations)

      assert_equal 4.5, aggregated["accuracy"]
      assert_equal 4.5, aggregated["tone"]
    end

    test "should handle missing criteria in some evaluations" do
      @response.evaluations.create!(
        evaluator_type: "human",
        evaluator_id: "u1",
        score: 4.0,
        score_min: 0,
        score_max: 5,
        criteria_scores: { "accuracy" => 4.0 }
      )

      @response.evaluations.create!(
        evaluator_type: "human",
        evaluator_id: "u2",
        score: 5.0,
        score_min: 0,
        score_max: 5,
        criteria_scores: { "accuracy" => 5.0, "tone" => 4.0 }
      )

      aggregated = EvaluationHelpers.aggregate_criteria_scores(@response.evaluations)

      assert_equal 4.5, aggregated["accuracy"]
      assert_equal 4.0, aggregated["tone"]
    end

    # score_distribution tests

    test "should calculate score distribution" do
      5.times do |i|
        @response.evaluations.create!(
          evaluator_type: "human",
          evaluator_id: "u#{i}",
          score: i + 1,
          score_min: 0,
          score_max: 5
        )
      end

      distribution = EvaluationHelpers.score_distribution(@response.evaluations, buckets: 5)

      # With scores 1,2,3,4,5 (normalized to 0.2,0.4,0.6,0.8,1.0), we get 4 buckets
      # because 0.8 and 1.0 fall in the same bucket (0.8-1.0)
      assert_equal 4, distribution.keys.length
      assert_equal 5, distribution.values.sum
    end
  end
end
