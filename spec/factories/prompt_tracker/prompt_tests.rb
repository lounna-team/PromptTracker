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
FactoryBot.define do
  factory :prompt_test, class: "PromptTracker::PromptTest" do
    association :prompt_version, factory: :prompt_version
    prompt_test_suite { nil }

    sequence(:name) { |n| "test_#{n}" }
    description { "Test description" }
    template_variables { { name: "John", role: "customer" } }
    expected_patterns { ["Hello", "John"] }
    expected_output { nil }
    model_config { { provider: "openai", model: "gpt-4", temperature: 0.7 } }
    evaluator_configs do
      [
        {
          evaluator_key: "length_check",
          threshold: 80,
          config: { min_length: 10, max_length: 500 }
        }
      ]
    end
    enabled { true }
    tags { ["smoke"] }
    metadata { {} }
  end
end
