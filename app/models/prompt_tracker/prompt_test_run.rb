# frozen_string_literal: true

# == Schema Information
#
# Table name: prompt_tracker_prompt_test_runs
#
#  assertion_results        :jsonb            not null
#  cost_usd                 :decimal(10, 6)
#  created_at               :datetime         not null
#  error_message            :text
#  evaluator_results        :jsonb            not null
#  execution_time_ms        :integer
#  failed_evaluators        :integer          default(0), not null
#  id                       :bigint           not null, primary key
#  llm_response_id          :bigint
#  metadata                 :jsonb            not null
#  passed                   :boolean
#  passed_evaluators        :integer          default(0), not null
#  prompt_test_id           :bigint           not null
#  prompt_test_suite_run_id :bigint
#  prompt_version_id        :bigint           not null
#  status                   :string           default("pending"), not null
#  total_evaluators         :integer          default(0), not null
#  updated_at               :datetime         not null
#
module PromptTracker
  # Represents the result of running a single test.
  #
  # Records all details about test execution including:
  # - Pass/fail status
  # - Evaluator results
  # - Assertion results
  # - Performance metrics
  # - Error details
  #
  # @example Access test run results
  #   run = PromptTestRun.last
  #   puts "Status: #{run.status}"
  #   puts "Passed: #{run.passed?}"
  #   puts "Evaluators: #{run.passed_evaluators}/#{run.total_evaluators}"
  #   puts "Time: #{run.execution_time_ms}ms"
  #
  class PromptTestRun < ApplicationRecord
    # Associations
    belongs_to :prompt_test
    belongs_to :prompt_version
    belongs_to :llm_response, optional: true
    belongs_to :prompt_test_suite_run, optional: true
    
    # Validations
    validates :status, presence: true
    validates :status, inclusion: { in: %w[pending running passed failed error skipped] }
    
    # Scopes
    scope :passed, -> { where(passed: true) }
    scope :failed, -> { where(passed: false) }
    scope :pending, -> { where(status: 'pending') }
    scope :running, -> { where(status: 'running') }
    scope :completed, -> { where(status: ['passed', 'failed', 'error']) }
    scope :recent, -> { order(created_at: :desc) }
    
    # Status helpers
    def pending?
      status == 'pending'
    end
    
    def running?
      status == 'running'
    end
    
    def completed?
      %w[passed failed error skipped].include?(status)
    end
    
    def error?
      status == 'error'
    end
    
    def skipped?
      status == 'skipped'
    end
    
    # Get evaluator pass rate
    #
    # @return [Float] percentage of evaluators that passed
    def evaluator_pass_rate
      return 0.0 if total_evaluators.zero?
      (passed_evaluators.to_f / total_evaluators * 100).round(2)
    end
    
    # Get failed evaluator details
    #
    # @return [Array<Hash>] array of failed evaluator results
    def failed_evaluator_details
      (evaluator_results || []).select { |r| !r['passed'] }
    end
    
    # Get passed evaluator details
    #
    # @return [Array<Hash>] array of passed evaluator results
    def passed_evaluator_details
      (evaluator_results || []).select { |r| r['passed'] }
    end
    
    # Get assertion failures
    #
    # @return [Array<String>] array of failed assertion messages
    def assertion_failures
      (assertion_results || {}).select { |_k, v| !v }.keys
    end
    
    # Get assertion successes
    #
    # @return [Array<String>] array of passed assertion names
    def assertion_successes
      (assertion_results || {}).select { |_k, v| v }.keys
    end
    
    # Check if all assertions passed
    #
    # @return [Boolean]
    def all_assertions_passed?
      assertion_failures.empty? && assertion_results.present?
    end
    
    # Check if all evaluators passed
    #
    # @return [Boolean]
    def all_evaluators_passed?
      failed_evaluators.zero? && total_evaluators.positive?
    end
  end
end

