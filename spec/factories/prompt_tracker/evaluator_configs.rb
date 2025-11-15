# frozen_string_literal: true

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
