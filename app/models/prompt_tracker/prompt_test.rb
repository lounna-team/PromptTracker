# frozen_string_literal: true

# == Schema Information
#
# Table name: prompt_tracker_prompt_tests
#
#  created_at           :datetime         not null
#  description          :text
#  enabled              :boolean          default(TRUE), not null
#  evaluator_configs    :jsonb            not null
#  expected_output      :text
#  expected_patterns    :jsonb            not null
#  id                   :bigint           not null, primary key
#  metadata             :jsonb            not null
#  model_config         :jsonb            not null
#  name                 :string           not null
#  prompt_test_suite_id :bigint
#  prompt_version_id    :bigint           not null
#  tags                 :jsonb            not null
#  template_variables   :jsonb            not null
#  updated_at           :datetime         not null
#
module PromptTracker
  # Represents a single test case for a prompt.
  #
  # A PromptTest defines:
  # - Input variables to use
  # - Expected output patterns or exact matches
  # - Evaluators to run with their thresholds
  # - Model configuration for LLM calls
  #
  # @example Create a test
  #   PromptTest.create!(
  #     prompt: greeting_prompt,
  #     name: "greeting_premium_user",
  #     description: "Test greeting for premium customers",
  #     template_variables: { customer_name: "Alice", account_type: "premium" },
  #     expected_patterns: [/Hello Alice/, /premium/],
  #     model_config: { provider: "openai", model: "gpt-4" },
  #     evaluator_configs: [
  #       { evaluator_key: :length_check, threshold: 80, config: { min_length: 50 } }
  #     ]
  #   )
  #
  class PromptTest < ApplicationRecord
    # Associations
    belongs_to :prompt_version
    belongs_to :prompt_test_suite, optional: true
    has_many :prompt_test_runs, dependent: :destroy

    # Delegate to get the prompt through prompt_version
    has_one :prompt, through: :prompt_version

    # Validations
    validates :name, presence: true
    validates :name, uniqueness: { scope: :prompt_version_id }
    validates :template_variables, presence: true
    validates :model_config, presence: true

    # Scopes
    scope :enabled, -> { where(enabled: true) }
    scope :disabled, -> { where(enabled: false) }
    scope :with_tag, ->(tag) { where("tags @> ?", [tag].to_json) }
    scope :recent, -> { order(created_at: :desc) }

    # Get recent test runs
    #
    # @param limit [Integer] number of runs to return
    # @return [ActiveRecord::Relation<PromptTestRun>]
    def recent_runs(limit = 10)
      prompt_test_runs.order(created_at: :desc).limit(limit)
    end

    # Calculate pass rate
    #
    # @param limit [Integer] number of recent runs to consider
    # @return [Float] pass rate as percentage (0-100)
    def pass_rate(limit: 30)
      runs = recent_runs(limit).where.not(passed: nil)
      return 0.0 if runs.empty?

      passed_count = runs.where(passed: true).count
      (passed_count.to_f / runs.count * 100).round(2)
    end

    # Get last test run
    #
    # @return [PromptTestRun, nil]
    def last_run
      prompt_test_runs.order(created_at: :desc).first
    end

    # Check if test is passing
    #
    # @return [Boolean]
    def passing?
      last_run&.passed? || false
    end

    # Get average execution time
    #
    # @param limit [Integer] number of recent runs to consider
    # @return [Integer, nil] average time in milliseconds
    def avg_execution_time(limit: 30)
      runs = recent_runs(limit).where.not(execution_time_ms: nil)
      return nil if runs.empty?

      runs.average(:execution_time_ms).to_i
    end

    # Get tags as array
    #
    # @return [Array<String>]
    def tag_list
      tags || []
    end

    # Add a tag
    #
    # @param tag [String] tag to add
    # @return [void]
    def add_tag(tag)
      self.tags = (tag_list + [tag]).uniq
      save
    end

    # Remove a tag
    #
    # @param tag [String] tag to remove
    # @return [void]
    def remove_tag(tag)
      self.tags = tag_list - [tag]
      save
    end
  end
end
