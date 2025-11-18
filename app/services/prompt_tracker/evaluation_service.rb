# frozen_string_literal: true

module PromptTracker
  # Service for creating evaluations of LLM responses.
  #
  # Supports three types of evaluations:
  # 1. Human evaluations - Manual review and rating
  # 2. Automated evaluations - Rule-based scoring
  # 3. LLM Judge evaluations - Using another LLM to evaluate
  #
  # @example Creating a human evaluation
  #   EvaluationService.create_human(
  #     llm_response: response,
  #     score: 4.5,
  #     evaluator_id: "john@example.com",
  #     criteria_scores: { "helpfulness" => 5, "tone" => 4 },
  #     feedback: "Great response!"
  #   )
  #
  # @example Creating an automated evaluation
  #   EvaluationService.create_automated(
  #     llm_response: response,
  #     evaluator_id: "length_validator_v1",
  #     score: 85,
  #     score_max: 100
  #   )
  #
  # @example Creating an LLM judge evaluation
  #   EvaluationService.create_llm_judge(
  #     llm_response: response,
  #     judge_model: "gpt-4",
  #     score: 4.2,
  #     criteria_scores: { "accuracy" => 4.5, "helpfulness" => 4.0 }
  #   )
  #
  class EvaluationService
    # Custom error classes
    class InvalidScoreError < StandardError; end
    class MissingResponseError < StandardError; end

    # Create a human evaluation
    #
    # @param llm_response [LlmResponse] the response to evaluate
    # @param score [Numeric] the overall score
    # @param evaluator_id [String] identifier for the human evaluator (e.g., email)
    # @param score_min [Numeric] minimum possible score (default: 0)
    # @param score_max [Numeric] maximum possible score (default: 5)
    # @param criteria_scores [Hash] optional breakdown by criteria
    # @param feedback [String] optional text feedback
    # @param metadata [Hash] optional additional metadata
    # @return [Evaluation] the created evaluation
    #
    # @example
    #   evaluation = EvaluationService.create_human(
    #     llm_response: response,
    #     score: 4.5,
    #     evaluator_id: "john@example.com",
    #     criteria_scores: {
    #       "helpfulness" => 5,
    #       "tone" => 4,
    #       "accuracy" => 4.5
    #     },
    #     feedback: "Very helpful response, could be more concise"
    #   )
    def self.create_human(llm_response:, score:, evaluator_id:,
                          score_min: 0, score_max: 5,
                          criteria_scores: nil, feedback: nil, metadata: nil)
      validate_response!(llm_response)
      validate_score!(score, score_min, score_max)

      Evaluation.create!(
        llm_response: llm_response,
        evaluator_type: "human",
        evaluator_id: evaluator_id,
        score: score,
        score_min: score_min,
        score_max: score_max,
        criteria_scores: criteria_scores || {},
        feedback: feedback,
        metadata: metadata || {}
      )
    end

    # Create an automated evaluation
    #
    # @param llm_response [LlmResponse] the response to evaluate
    # @param evaluator_id [String] identifier for the automated evaluator
    # @param score [Numeric] the overall score
    # @param score_min [Numeric] minimum possible score (default: 0)
    # @param score_max [Numeric] maximum possible score (default: 100)
    # @param criteria_scores [Hash] optional breakdown by criteria
    # @param feedback [String] optional text feedback
    # @param metadata [Hash] optional additional metadata
    # @return [Evaluation] the created evaluation
    #
    # @example
    #   evaluation = EvaluationService.create_automated(
    #     llm_response: response,
    #     evaluator_id: "sentiment_analyzer_v1",
    #     score: 85,
    #     score_max: 100,
    #     metadata: { sentiment: "positive", confidence: 0.85 }
    #   )
    def self.create_automated(llm_response:, evaluator_id:, score:,
                              score_min: 0, score_max: 100,
                              criteria_scores: nil, feedback: nil, metadata: nil)
      validate_response!(llm_response)
      validate_score!(score, score_min, score_max)

      Evaluation.create!(
        llm_response: llm_response,
        evaluator_type: "automated",
        evaluator_id: evaluator_id,
        score: score,
        score_min: score_min,
        score_max: score_max,
        criteria_scores: criteria_scores || {},
        feedback: feedback,
        metadata: metadata || {}
      )
    end

    # Create an LLM judge evaluation
    #
    # @param llm_response [LlmResponse] the response to evaluate
    # @param judge_model [String] the LLM model used as judge (e.g., "gpt-4")
    # @param score [Numeric] the overall score
    # @param score_min [Numeric] minimum possible score (default: 0)
    # @param score_max [Numeric] maximum possible score (default: 5)
    # @param criteria_scores [Hash] optional breakdown by criteria
    # @param feedback [String] optional text feedback from the judge
    # @param metadata [Hash] optional additional metadata
    # @return [Evaluation] the created evaluation
    #
    # @example
    #   evaluation = EvaluationService.create_llm_judge(
    #     llm_response: response,
    #     judge_model: "gpt-4",
    #     score: 4.2,
    #     criteria_scores: {
    #       "accuracy" => 4.5,
    #       "helpfulness" => 4.0,
    #       "tone" => 4.0
    #     },
    #     feedback: "The response is accurate and helpful..."
    #   )
    def self.create_llm_judge(llm_response:, judge_model:, score:,
                              score_min: 0, score_max: 5,
                              criteria_scores: nil, feedback: nil, metadata: nil)
      validate_response!(llm_response)
      validate_score!(score, score_min, score_max)

      # Store judge model in evaluator_id
      evaluator_id = "llm_judge:#{judge_model}"

      Evaluation.create!(
        llm_response: llm_response,
        evaluator_type: "llm_judge",
        evaluator_id: evaluator_id,
        score: score,
        score_min: score_min,
        score_max: score_max,
        criteria_scores: criteria_scores || {},
        feedback: feedback,
        metadata: (metadata || {}).merge(judge_model: judge_model)
      )
    end

    # Validate that the LLM response exists
    #
    # @param llm_response [LlmResponse] the response to validate
    # @raise [MissingResponseError] if response is nil
    def self.validate_response!(llm_response)
      raise MissingResponseError, "LLM response is required" if llm_response.nil?
    end

    # Validate that the score is within the valid range
    #
    # @param score [Numeric] the score to validate
    # @param score_min [Numeric] minimum valid score
    # @param score_max [Numeric] maximum valid score
    # @raise [InvalidScoreError] if score is outside the valid range
    def self.validate_score!(score, score_min, score_max)
      return if score.nil?
      if score < score_min || score > score_max
        raise InvalidScoreError,
              "Score #{score} is outside valid range [#{score_min}, #{score_max}]"
      end
    end

    private_class_method :validate_response!, :validate_score!
  end
end
