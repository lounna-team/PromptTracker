# frozen_string_literal: true

# == Schema Information
#
# Table name: prompt_tracker_prompt_test_suite_runs
#
#  created_at           :datetime         not null
#  error_tests          :integer          default(0), not null
#  failed_tests         :integer          default(0), not null
#  id                   :bigint           not null, primary key
#  metadata             :jsonb            not null
#  passed_tests         :integer          default(0), not null
#  prompt_test_suite_id :bigint           not null
#  skipped_tests        :integer          default(0), not null
#  status               :string           default("pending"), not null
#  total_cost_usd       :decimal(10, 6)
#  total_duration_ms    :integer
#  total_tests          :integer          default(0), not null
#  triggered_by         :string
#  updated_at           :datetime         not null
#
module PromptTracker
  # Represents the result of running a test suite.
  #
  # Aggregates results from all test runs in the suite.
  #
  # @example Access suite run results
  #   suite_run = PromptTestSuiteRun.last
  #   puts "Status: #{suite_run.status}"
  #   puts "Passed: #{suite_run.passed_tests}/#{suite_run.total_tests}"
  #   puts "Duration: #{suite_run.total_duration_ms}ms"
  #
  class PromptTestSuiteRun < ApplicationRecord
    # Associations
    belongs_to :prompt_test_suite
    has_many :prompt_test_runs, dependent: :nullify
    
    # Validations
    validates :status, presence: true
    validates :status, inclusion: { in: %w[pending running passed failed partial error] }
    
    # Scopes
    scope :passed, -> { where(status: 'passed') }
    scope :failed, -> { where(status: 'failed') }
    scope :pending, -> { where(status: 'pending') }
    scope :running, -> { where(status: 'running') }
    scope :completed, -> { where(status: ['passed', 'failed', 'partial', 'error']) }
    scope :recent, -> { order(created_at: :desc) }
    
    # Status helpers
    def pending?
      status == 'pending'
    end
    
    def running?
      status == 'running'
    end
    
    def passed?
      status == 'passed'
    end
    
    def failed?
      status == 'failed'
    end
    
    def partial?
      status == 'partial'
    end
    
    def error?
      status == 'error'
    end
    
    def completed?
      %w[passed failed partial error].include?(status)
    end
    
    # Get pass rate
    #
    # @return [Float] percentage of tests that passed
    def pass_rate
      return 0.0 if total_tests.zero?
      (passed_tests.to_f / total_tests * 100).round(2)
    end
    
    # Get average execution time per test
    #
    # @return [Integer, nil] average time in milliseconds
    def avg_test_duration
      return nil if total_tests.zero? || total_duration_ms.nil?
      (total_duration_ms.to_f / total_tests).round
    end
    
    # Get failed test runs
    #
    # @return [ActiveRecord::Relation<PromptTestRun>]
    def failed_test_runs
      prompt_test_runs.failed
    end
    
    # Get passed test runs
    #
    # @return [ActiveRecord::Relation<PromptTestRun>]
    def passed_test_runs
      prompt_test_runs.passed
    end
    
    # Get error test runs
    #
    # @return [ActiveRecord::Relation<PromptTestRun>]
    def error_test_runs
      prompt_test_runs.where(status: 'error')
    end
    
    # Check if all tests passed
    #
    # @return [Boolean]
    def all_passed?
      passed_tests == total_tests && total_tests.positive?
    end
    
    # Check if any tests failed
    #
    # @return [Boolean]
    def any_failed?
      failed_tests.positive?
    end
  end
end

