# frozen_string_literal: true

# == Schema Information
#
# Table name: prompt_tracker_evaluations
#
#  created_at      :datetime         not null
#  criteria_scores :jsonb
#  evaluator_id    :string
#  evaluator_type  :string           not null
#  feedback        :text
#  id              :bigint           not null, primary key
#  llm_response_id :bigint           not null
#  metadata        :jsonb
#  score           :decimal(10, 2)   not null
#  score_max       :decimal(10, 2)   default(5.0)
#  score_min       :decimal(10, 2)   default(0.0)
#  updated_at      :datetime         not null
#
require "test_helper"

module PromptTracker
  class EvaluationTest < ActiveSupport::TestCase
    # Setup
    def setup
      @prompt = Prompt.create!(
        name: "test_prompt",
        description: "A test prompt"
      )

      @version = @prompt.prompt_versions.create!(
        template: "Hello {{name}}",
        status: "active",
        source: "file"
      )

      @response = @version.llm_responses.create!(
        rendered_prompt: "Hello John",
        variables_used: { "name" => "John" },
        provider: "openai",
        model: "gpt-4",
        status: "success"
      )

      @valid_attributes = {
        llm_response: @response,
        score: 4.5,
        score_min: 0,
        score_max: 5,
        criteria_scores: {
          "helpfulness" => 5,
          "tone" => 4,
          "accuracy" => 4.5
        },
        evaluator_type: "human",
        evaluator_id: "john@example.com",
        feedback: "Good response"
      }
    end

    # Validation Tests

    test "should be valid with valid attributes" do
      evaluation = Evaluation.new(@valid_attributes)
      assert evaluation.valid?, "Evaluation should be valid with valid attributes"
    end

    test "should require score" do
      evaluation = Evaluation.new(@valid_attributes.except(:score))
      assert_not evaluation.valid?
      assert_includes evaluation.errors[:score], "can't be blank"
    end

    test "should require evaluator_type" do
      evaluation = Evaluation.new(@valid_attributes.except(:evaluator_type))
      assert_not evaluation.valid?
      assert_includes evaluation.errors[:evaluator_type], "can't be blank"
    end

    test "should require valid evaluator_type" do
      Evaluation::EVALUATOR_TYPES.each do |type|
        evaluation = Evaluation.new(@valid_attributes.merge(evaluator_type: type))
        assert evaluation.valid?, "Evaluator type '#{type}' should be valid"
      end

      evaluation = Evaluation.new(@valid_attributes.merge(evaluator_type: "invalid"))
      assert_not evaluation.valid?
      assert_includes evaluation.errors[:evaluator_type], "is not included in the list"
    end

    test "should validate score is within range" do
      evaluation = Evaluation.new(@valid_attributes.merge(score: 3))
      assert evaluation.valid?

      evaluation = Evaluation.new(@valid_attributes.merge(score: -1))
      assert_not evaluation.valid?
      assert_includes evaluation.errors[:score], "must be greater than or equal to 0"

      evaluation = Evaluation.new(@valid_attributes.merge(score: 6))
      assert_not evaluation.valid?
      assert_includes evaluation.errors[:score], "must be less than or equal to 5"
    end

    test "should validate criteria_scores is a hash" do
      evaluation = Evaluation.new(@valid_attributes.merge(criteria_scores: {}))
      assert evaluation.valid?

      evaluation = Evaluation.new(@valid_attributes.merge(criteria_scores: "not a hash"))
      assert_not evaluation.valid?
      assert_includes evaluation.errors[:criteria_scores], "must be a hash"
    end

    test "should validate metadata is a hash" do
      evaluation = Evaluation.new(@valid_attributes.merge(metadata: {}))
      assert evaluation.valid?

      evaluation = Evaluation.new(@valid_attributes.merge(metadata: "not a hash"))
      assert_not evaluation.valid?
      assert_includes evaluation.errors[:metadata], "must be a hash"
    end

    # Association Tests

    test "should belong to llm_response" do
      evaluation = Evaluation.create!(@valid_attributes)
      assert_equal @response, evaluation.llm_response
    end

    test "should have access to prompt_version through llm_response" do
      evaluation = Evaluation.create!(@valid_attributes)
      assert_equal @version, evaluation.prompt_version
    end

    test "should have access to prompt through prompt_version" do
      evaluation = Evaluation.create!(@valid_attributes)
      assert_equal @prompt, evaluation.prompt
    end

    # Scope Tests

    test "by_humans scope should return only human evaluations" do
      human = Evaluation.create!(@valid_attributes.merge(evaluator_type: "human"))
      automated = Evaluation.create!(@valid_attributes.merge(evaluator_type: "automated"))

      human_evaluations = Evaluation.by_humans
      assert_includes human_evaluations, human
      assert_not_includes human_evaluations, automated
    end

    test "automated scope should return only automated evaluations" do
      human = Evaluation.create!(@valid_attributes.merge(evaluator_type: "human"))
      automated = Evaluation.create!(@valid_attributes.merge(evaluator_type: "automated"))

      automated_evaluations = Evaluation.automated
      assert_includes automated_evaluations, automated
      assert_not_includes automated_evaluations, human
    end

    test "by_llm_judge scope should return only llm_judge evaluations" do
      human = Evaluation.create!(@valid_attributes.merge(evaluator_type: "human"))
      llm_judge = Evaluation.create!(@valid_attributes.merge(evaluator_type: "llm_judge"))

      llm_judge_evaluations = Evaluation.by_llm_judge
      assert_includes llm_judge_evaluations, llm_judge
      assert_not_includes llm_judge_evaluations, human
    end

    test "by_evaluator scope should filter by evaluator_id" do
      john = Evaluation.create!(@valid_attributes.merge(evaluator_id: "john@example.com"))
      jane = Evaluation.create!(@valid_attributes.merge(evaluator_id: "jane@example.com"))

      john_evaluations = Evaluation.by_evaluator("john@example.com")
      assert_includes john_evaluations, john
      assert_not_includes john_evaluations, jane
    end

    test "above_score scope should return evaluations above threshold" do
      high = Evaluation.create!(@valid_attributes.merge(score: 4.5))
      low = Evaluation.create!(@valid_attributes.merge(score: 2.0))

      high_scores = Evaluation.above_score(4.0)
      assert_includes high_scores, high
      assert_not_includes high_scores, low
    end

    test "below_score scope should return evaluations below threshold" do
      high = Evaluation.create!(@valid_attributes.merge(score: 4.5))
      low = Evaluation.create!(@valid_attributes.merge(score: 2.0))

      low_scores = Evaluation.below_score(3.0)
      assert_includes low_scores, low
      assert_not_includes low_scores, high
    end

    test "recent scope should return evaluations from last 24 hours" do
      recent = Evaluation.create!(@valid_attributes)
      old = Evaluation.create!(@valid_attributes.merge(created_at: 2.days.ago))

      recent_evaluations = Evaluation.recent
      assert_includes recent_evaluations, recent
      assert_not_includes recent_evaluations, old
    end

    # Type Check Methods

    test "human? should return true for human evaluations" do
      evaluation = Evaluation.create!(@valid_attributes.merge(evaluator_type: "human"))
      assert evaluation.human?
    end

    test "automated? should return true for automated evaluations" do
      evaluation = Evaluation.create!(@valid_attributes.merge(evaluator_type: "automated"))
      assert evaluation.automated?
    end

    test "llm_judge? should return true for llm_judge evaluations" do
      evaluation = Evaluation.create!(@valid_attributes.merge(evaluator_type: "llm_judge"))
      assert evaluation.llm_judge?
    end

    # Score Calculation Methods

    test "normalized_score should return score on 0-1 scale" do
      evaluation = Evaluation.create!(@valid_attributes.merge(
        score: 4.5,
        score_min: 0,
        score_max: 5
      ))

      assert_in_delta 0.9, evaluation.normalized_score, 0.01
    end

    test "normalized_score should handle different scales" do
      evaluation = Evaluation.create!(@valid_attributes.merge(
        score: 75,
        score_min: 0,
        score_max: 100
      ))

      assert_in_delta 0.75, evaluation.normalized_score, 0.01
    end

    test "normalized_score should return 0 when min equals max" do
      evaluation = Evaluation.create!(@valid_attributes.merge(
        score: 5,
        score_min: 5,
        score_max: 5
      ))

      assert_equal 0.0, evaluation.normalized_score
    end

    test "score_percentage should return score as percentage" do
      evaluation = Evaluation.create!(@valid_attributes.merge(
        score: 4.5,
        score_min: 0,
        score_max: 5
      ))

      assert_in_delta 90.0, evaluation.score_percentage, 0.1
    end

    test "passing? should return true when score is above threshold" do
      evaluation = Evaluation.create!(@valid_attributes.merge(
        score: 4.5,
        score_min: 0,
        score_max: 5
      ))

      assert evaluation.passing?(70) # 90% > 70%
      assert_not evaluation.passing?(95) # 90% < 95%
    end

    # Criteria Methods

    test "criterion_score should return score for specific criterion" do
      evaluation = Evaluation.create!(@valid_attributes)

      assert_equal 5, evaluation.criterion_score("helpfulness")
      assert_equal 4, evaluation.criterion_score("tone")
      assert_equal 4.5, evaluation.criterion_score("accuracy")
    end

    test "criterion_score should work with symbol keys" do
      evaluation = Evaluation.create!(@valid_attributes)
      assert_equal 5, evaluation.criterion_score(:helpfulness)
    end

    test "criterion_score should return nil for non-existent criterion" do
      evaluation = Evaluation.create!(@valid_attributes)
      assert_nil evaluation.criterion_score("nonexistent")
    end

    test "criteria_names should return all criterion names" do
      evaluation = Evaluation.create!(@valid_attributes)
      names = evaluation.criteria_names

      assert_includes names, "helpfulness"
      assert_includes names, "tone"
      assert_includes names, "accuracy"
      assert_equal 3, names.length
    end

    test "has_criteria_scores? should return true when criteria exist" do
      evaluation = Evaluation.create!(@valid_attributes)
      assert evaluation.has_criteria_scores?
    end

    test "has_criteria_scores? should return false when criteria are empty" do
      evaluation = Evaluation.create!(@valid_attributes.merge(criteria_scores: {}))
      assert_not evaluation.has_criteria_scores?
    end

    # Summary Method

    test "summary should return human-readable summary" do
      evaluation = Evaluation.create!(@valid_attributes.merge(
        score: 4.5,
        score_min: 0,
        score_max: 5,
        evaluator_type: "human"
      ))

      assert_equal "Human: 4.5/5 (90.0%)", evaluation.summary
    end

    test "summary should work for different evaluator types" do
      automated = Evaluation.create!(@valid_attributes.merge(
        evaluator_type: "automated",
        score: 85,
        score_max: 100
      ))

      assert_equal "Automated: 85/100 (85.0%)", automated.summary
    end
  end
end

