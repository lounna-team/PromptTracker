# frozen_string_literal: true

# == Schema Information
#
# Table name: prompt_tracker_evaluator_configs
#
#  config               :jsonb            not null
#  created_at           :datetime         not null
#  depends_on           :string
#  enabled              :boolean          default(TRUE), not null
#  evaluator_key        :string           not null
#  id                   :bigint           not null, primary key
#  min_dependency_score :integer
#  priority             :integer          default(0), not null
#  prompt_id            :bigint           not null
#  run_mode             :string           default("async"), not null
#  updated_at           :datetime         not null
#  weight               :decimal(5, 2)    default(1.0), not null
#
module PromptTracker
  # Represents configuration for an evaluator that should run automatically for a prompt.
  #
  # EvaluatorConfigs define which evaluators run when a response is created,
  # along with their parameters, weights, execution mode, and dependencies.
  #
  # @example Creating a basic evaluator config
  #   prompt.evaluator_configs.create!(
  #     evaluator_key: :length_check,
  #     enabled: true,
  #     run_mode: "sync",
  #     weight: 0.15,
  #     config: { min_length: 50, max_length: 500 }
  #   )
  #
  # @example Creating a dependent evaluator config
  #   prompt.evaluator_configs.create!(
  #     evaluator_key: :gpt4_judge,
  #     enabled: true,
  #     run_mode: "async",
  #     weight: 0.30,
  #     depends_on: "keyword_check",
  #     min_dependency_score: 90,
  #     config: { judge_model: "gpt-4", criteria: ["accuracy", "helpfulness"] }
  #   )
  #
  # @example Finding enabled configs for a prompt
  #   configs = prompt.evaluator_configs.enabled.by_priority
  #   configs.each { |config| puts "#{config.evaluator_key}: priority #{config.priority}" }
  #
  class EvaluatorConfig < ApplicationRecord
    # Associations
    belongs_to :prompt,
               class_name: "PromptTracker::Prompt",
               inverse_of: :evaluator_configs

    # Validations
    validates :evaluator_key,
              presence: true,
              uniqueness: { scope: :prompt_id }

    validates :run_mode,
              presence: true,
              inclusion: { in: %w[sync async] }

    validates :priority,
              presence: true,
              numericality: { only_integer: true }

    validates :weight,
              presence: true,
              numericality: { greater_than_or_equal_to: 0 }

    validates :min_dependency_score,
              numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 },
              allow_nil: true

    validate :dependency_exists, if: :depends_on?
    validate :no_circular_dependencies

    # Scopes

    # Returns only enabled evaluator configs
    # @return [ActiveRecord::Relation<EvaluatorConfig>]
    scope :enabled, -> { where(enabled: true) }

    # Returns configs ordered by priority (highest first)
    # @return [ActiveRecord::Relation<EvaluatorConfig>]
    scope :by_priority, -> { order(priority: :desc) }

    # Returns configs with no dependencies (independent evaluators)
    # @return [ActiveRecord::Relation<EvaluatorConfig>]
    scope :independent, -> { where(depends_on: nil) }

    # Returns configs with dependencies (dependent evaluators)
    # @return [ActiveRecord::Relation<EvaluatorConfig>]
    scope :dependent, -> { where.not(depends_on: nil) }

    # Instance Methods

    # Returns metadata about this evaluator from the registry
    # @return [Hash, nil] evaluator metadata or nil if not found
    def evaluator_metadata
      EvaluatorRegistry.get(evaluator_key)
    end

    # Builds an instance of the evaluator for a specific response
    # @param llm_response [LlmResponse] the response to evaluate
    # @return [BaseEvaluator] an instance of the evaluator
    def build_evaluator(llm_response)
      EvaluatorRegistry.build(evaluator_key, llm_response, config)
    end

    # Checks if this config is set to run synchronously
    # @return [Boolean] true if run_mode is "sync"
    def sync?
      run_mode == "sync"
    end

    # Checks if this config is set to run asynchronously
    # @return [Boolean] true if run_mode is "async"
    def async?
      run_mode == "async"
    end

    # Checks if this config has a dependency
    # @return [Boolean] true if depends_on is present
    def has_dependency?
      depends_on.present?
    end

    # Checks if the dependency requirement is met for a given response
    # @param llm_response [LlmResponse] the response to check
    # @return [Boolean] true if dependency is met or no dependency exists
    def dependency_met?(llm_response)
      return true unless has_dependency?

      # Get the actual evaluator_id from the registry
      # The depends_on field stores the registry key (e.g., "length_check")
      # but evaluations are stored with the evaluator_id (e.g., "length_evaluator_v1")
      dependency_config = prompt.evaluator_configs.find_by(evaluator_key: depends_on)
      return false unless dependency_config

      # Build the evaluator to get its evaluator_id
      dependency_evaluator = dependency_config.build_evaluator(llm_response)
      actual_evaluator_id = dependency_evaluator.evaluator_id

      dependency_eval = llm_response.evaluations.find_by(evaluator_id: actual_evaluator_id)
      return false unless dependency_eval

      min_score = min_dependency_score || 80
      dependency_eval.score >= min_score
    end

    # Returns the normalized weight (relative to all enabled configs for this prompt)
    # @return [Float] normalized weight between 0 and 1
    def normalized_weight
      total_weight = prompt.evaluator_configs.enabled.sum(:weight)
      total_weight > 0 ? (weight / total_weight) : 0
    end

    # Returns a human-readable name for this evaluator
    # @return [String] evaluator name from metadata or key
    def name
      evaluator_metadata&.dig(:name) || evaluator_key.to_s.titleize
    end

    # Returns a description of this evaluator
    # @return [String, nil] evaluator description from metadata
    def description
      evaluator_metadata&.dig(:description)
    end

    private

    # Validates that the dependency evaluator exists for this prompt
    def dependency_exists
      return unless depends_on.present?

      unless prompt.evaluator_configs.exists?(evaluator_key: depends_on)
        errors.add(:depends_on, "evaluator '#{depends_on}' must be configured for this prompt")
      end
    end

    # Validates that there are no circular dependencies
    def no_circular_dependencies
      return unless depends_on.present?

      visited = Set.new([evaluator_key.to_s])
      current = depends_on

      while current.present?
        if visited.include?(current)
          errors.add(:depends_on, "creates a circular dependency")
          break
        end

        visited.add(current)
        dependency_config = prompt.evaluator_configs.find_by(evaluator_key: current)
        current = dependency_config&.depends_on
      end
    end
  end
end
