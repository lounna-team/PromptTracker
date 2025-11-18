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
FactoryBot.define do
  factory :prompt_test_suite_run, class: "PromptTracker::PromptTestSuiteRun" do
    association :prompt_test_suite, factory: :prompt_test_suite

    status { "passed" }
    total_tests { 10 }
    passed_tests { 10 }
    failed_tests { 0 }
    skipped_tests { 0 }
    error_tests { 0 }
    total_duration_ms { 15000 }
    total_cost_usd { 0.02 }
    triggered_by { "manual" }
    metadata { {} }

    trait :failed do
      status { "failed" }
      passed_tests { 7 }
      failed_tests { 3 }
    end

    trait :partial do
      status { "partial" }
      passed_tests { 8 }
      failed_tests { 1 }
      skipped_tests { 1 }
    end
  end
end

