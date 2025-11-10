# frozen_string_literal: true

module PromptTracker
  # Represents a quality evaluation of an LLM response.
  #
  # Evaluations can be created by:
  # - Humans: Manual review and rating
  # - Automated systems: Rule-based scoring
  # - LLM judges: Another LLM evaluates the response
  #
  # @example Creating a human evaluation
  #   evaluation = Evaluation.create!(
  #     llm_response: response,
  #     score: 4.5,
  #     score_min: 0,
  #     score_max: 5,
  #     criteria_scores: {
  #       "helpfulness" => 5,
  #       "tone" => 4,
  #       "accuracy" => 4.5
  #     },
  #     evaluator_type: "human",
  #     evaluator_id: "john@example.com",
  #     feedback: "Good response, but could be more concise"
  #   )
  #
  # @example Creating an automated evaluation
  #   evaluation = Evaluation.create!(
  #     llm_response: response,
  #     score: 85,
  #     score_min: 0,
  #     score_max: 100,
  #     evaluator_type: "automated",
  #     evaluator_id: "sentiment_analyzer_v1"
  #   )
  #
  class Evaluation < ApplicationRecord
    # Constants
    EVALUATOR_TYPES = %w[human automated llm_judge].freeze

    # Associations
    belongs_to :llm_response,
               class_name: "PromptTracker::LlmResponse",
               inverse_of: :evaluations

    has_one :prompt_version,
            through: :llm_response,
            class_name: "PromptTracker::PromptVersion"

    has_one :prompt,
            through: :prompt_version,
            class_name: "PromptTracker::Prompt"

    # Validations
    validates :score, presence: true, numericality: true
    validates :score_min, numericality: true
    validates :score_max, numericality: true
    validates :evaluator_type, presence: true, inclusion: { in: EVALUATOR_TYPES }

    validate :score_within_range
    validate :criteria_scores_must_be_hash
    validate :metadata_must_be_hash

    # Scopes

    # Returns only human evaluations
    # @return [ActiveRecord::Relation<Evaluation>]
    scope :by_humans, -> { where(evaluator_type: "human") }

    # Returns only automated evaluations
    # @return [ActiveRecord::Relation<Evaluation>]
    scope :automated, -> { where(evaluator_type: "automated") }

    # Returns only LLM judge evaluations
    # @return [ActiveRecord::Relation<Evaluation>]
    scope :by_llm_judge, -> { where(evaluator_type: "llm_judge") }

    # Returns evaluations by a specific evaluator
    # @param evaluator_id [String] the evaluator identifier
    # @return [ActiveRecord::Relation<Evaluation>]
    scope :by_evaluator, ->(evaluator_id) { where(evaluator_id: evaluator_id) }

    # Returns evaluations with score above threshold
    # @param threshold [Numeric] the minimum score
    # @return [ActiveRecord::Relation<Evaluation>]
    scope :above_score, ->(threshold) { where("score >= ?", threshold) }

    # Returns evaluations with score below threshold
    # @param threshold [Numeric] the maximum score
    # @return [ActiveRecord::Relation<Evaluation>]
    scope :below_score, ->(threshold) { where("score <= ?", threshold) }

    # Returns recent evaluations (last 24 hours by default)
    # @param hours [Integer] number of hours to look back
    # @return [ActiveRecord::Relation<Evaluation>]
    scope :recent, ->(hours = 24) { where("created_at > ?", hours.hours.ago) }

    # Instance Methods

    # Checks if this is a human evaluation.
    #
    # @return [Boolean] true if evaluator_type is "human"
    def human?
      evaluator_type == "human"
    end

    # Checks if this is an automated evaluation.
    #
    # @return [Boolean] true if evaluator_type is "automated"
    def automated?
      evaluator_type == "automated"
    end

    # Checks if this is an LLM judge evaluation.
    #
    # @return [Boolean] true if evaluator_type is "llm_judge"
    def llm_judge?
      evaluator_type == "llm_judge"
    end

    # Normalizes the score to a 0-1 scale.
    #
    # @return [Float] normalized score between 0 and 1
    def normalized_score
      return 0.0 if score_max == score_min

      (score - score_min) / (score_max - score_min).to_f
    end

    # Converts the score to a percentage (0-100).
    #
    # @return [Float] score as percentage
    def score_percentage
      normalized_score * 100
    end

    # Checks if the score is passing (above 70% by default).
    #
    # @param threshold [Float] passing threshold as percentage (default: 70)
    # @return [Boolean] true if score is passing
    def passing?(threshold = 70)
      score_percentage >= threshold
    end

    # Returns the score for a specific criterion.
    #
    # @param criterion [String] the criterion name
    # @return [Numeric, nil] the score or nil if not found
    def criterion_score(criterion)
      criteria_scores[criterion.to_s]
    end

    # Returns all criteria names.
    #
    # @return [Array<String>] list of criterion names
    def criteria_names
      criteria_scores.keys
    end

    # Checks if this evaluation has detailed criteria scores.
    #
    # @return [Boolean] true if criteria_scores is not empty
    def has_criteria_scores?
      criteria_scores.present? && criteria_scores.any?
    end

    # Returns a human-readable summary of this evaluation.
    #
    # @return [String] summary
    def summary
      type_label = evaluator_type.humanize
      # Format numbers without unnecessary decimals
      score_formatted = score % 1 == 0 ? score.to_i : score
      max_formatted = score_max % 1 == 0 ? score_max.to_i : score_max
      score_label = "#{score_formatted}/#{max_formatted}"
      percentage = "(#{score_percentage.round(1)}%)"

      "#{type_label}: #{score_label} #{percentage}"
    end

    private

    # Validates that score is within the min/max range
    def score_within_range
      return if score.nil? || score_min.nil? || score_max.nil?

      # Format numbers without unnecessary decimals for error messages
      min_formatted = score_min % 1 == 0 ? score_min.to_i : score_min
      max_formatted = score_max % 1 == 0 ? score_max.to_i : score_max

      if score < score_min
        errors.add(:score, "must be greater than or equal to #{min_formatted}")
      elsif score > score_max
        errors.add(:score, "must be less than or equal to #{max_formatted}")
      end
    end

    # Validates that criteria_scores is a hash
    def criteria_scores_must_be_hash
      return if criteria_scores.nil? || criteria_scores.is_a?(Hash)

      errors.add(:criteria_scores, "must be a hash")
    end

    # Validates that metadata is a hash
    def metadata_must_be_hash
      return if metadata.nil? || metadata.is_a?(Hash)

      errors.add(:metadata, "must be a hash")
    end
  end
end
