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
FactoryBot.define do
  factory :prompt_test_suite, class: "PromptTracker::PromptTestSuite" do
    sequence(:name) { |n| "Test Suite #{n}" }
    description { "Test suite description" }
    prompt { nil }
    enabled { true }
    tags { ["smoke"] }
    metadata { {} }
  end
end
