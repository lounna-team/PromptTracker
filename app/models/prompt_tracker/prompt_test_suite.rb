# frozen_string_literal: true

# == Schema Information
#
# Table name: prompt_tracker_prompt_test_suites
#
#  created_at  :datetime         not null
#  description :text
#  enabled     :boolean          default(TRUE), not null
#  id          :bigint           not null, primary key
#  metadata    :jsonb            not null
#  name        :string           not null
#  prompt_id   :bigint
#  tags        :jsonb            not null
#  updated_at  :datetime         not null
#
module PromptTracker
  # Represents a collection of related tests.
  #
  # Test suites group tests together for organized execution.
  # They can be filtered by prompt or include tests from multiple prompts.
  #
  # @example Create a test suite
  #   suite = PromptTestSuite.create!(
  #     name: "Smoke Tests",
  #     description: "Critical tests that must pass before deployment",
  #     tags: ["smoke", "pre-deploy"]
  #   )
  #   suite.prompt_tests << [test1, test2, test3]
  #
  class PromptTestSuite < ApplicationRecord
    # Associations
    belongs_to :prompt, optional: true
    has_many :prompt_tests, dependent: :nullify
    has_many :prompt_test_suite_runs, dependent: :destroy
    
    # Validations
    validates :name, presence: true, uniqueness: true
    
    # Scopes
    scope :enabled, -> { where(enabled: true) }
    scope :disabled, -> { where(enabled: false) }
    scope :with_tag, ->(tag) { where("tags @> ?", [tag].to_json) }
    scope :recent, -> { order(created_at: :desc) }
    
    # Get enabled tests
    #
    # @return [ActiveRecord::Relation<PromptTest>]
    def enabled_tests
      prompt_tests.enabled
    end
    
    # Get recent suite runs
    #
    # @param limit [Integer] number of runs to return
    # @return [ActiveRecord::Relation<PromptTestSuiteRun>]
    def recent_runs(limit = 10)
      prompt_test_suite_runs.order(created_at: :desc).limit(limit)
    end
    
    # Calculate pass rate
    #
    # @param limit [Integer] number of recent runs to consider
    # @return [Float] pass rate as percentage (0-100)
    def pass_rate(limit: 30)
      runs = recent_runs(limit).where(status: ['passed', 'failed'])
      return 0.0 if runs.empty?
      
      passed_count = runs.where(status: 'passed').count
      (passed_count.to_f / runs.count * 100).round(2)
    end
    
    # Get last suite run
    #
    # @return [PromptTestSuiteRun, nil]
    def last_run
      prompt_test_suite_runs.order(created_at: :desc).first
    end
    
    # Check if suite is passing
    #
    # @return [Boolean]
    def passing?
      last_run&.passed? || false
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

