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
FactoryBot.define do
  factory :evaluator_config, class: "PromptTracker::EvaluatorConfig" do
    association :prompt, factory: :prompt
    evaluator_key { "length_check" }
    enabled { true }
    run_mode { "sync" }
    priority { 100 }
    weight { 1.0 }
    config do
      {
        "min_length" => 50,
        "max_length" => 500
      }
    end

    trait :disabled do
      enabled { false }
    end

    trait :async do
      run_mode { "async" }
    end

    trait :high_priority do
      priority { 200 }
    end

    trait :low_priority do
      priority { 50 }
    end

    trait :keyword_evaluator do
      evaluator_key { "keyword_check" }
      config do
        {
          "required_keywords" => [ "hello", "help" ],
          "forbidden_keywords" => [ "spam" ]
        }
      end
    end

    trait :format_evaluator do
      evaluator_key { "format_check" }
      config do
        {
          "format" => "json",
          "schema" => {
            "type" => "object",
            "required_keys" => [ "status", "message" ]
          }
        }
      end
    end

    trait :llm_judge do
      evaluator_key { "gpt4_judge" }
      run_mode { "async" }
      config do
        {
          "model" => "gpt-4",
          "criteria" => [ "accuracy", "helpfulness", "tone" ]
        }
      end
    end

    trait :with_dependency do
      evaluator_key { "keyword_check" }
      depends_on { "length_check" }
      min_dependency_score { 80 }
    end
  end
end
