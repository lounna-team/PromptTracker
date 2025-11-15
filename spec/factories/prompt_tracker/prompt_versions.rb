# frozen_string_literal: true

FactoryBot.define do
  factory :prompt_version, class: "PromptTracker::PromptVersion" do
    association :prompt, factory: :prompt
    template { "Hello {{name}}, how can I help you today?" }
    sequence(:version_number) { |n| n }
    status { "draft" }
    source { "web_ui" }
    variables_schema do
      [
        { "name" => "name", "type" => "string", "required" => true }
      ]
    end
    model_config { {} }
    notes { "Test version" }

    trait :active do
      status { "active" }
    end

    trait :deprecated do
      status { "deprecated" }
    end

    trait :from_file do
      source { "file" }
    end

    trait :from_api do
      source { "api" }
    end

    trait :with_model_config do
      model_config do
        {
          "model" => "gpt-4",
          "temperature" => 0.7,
          "max_tokens" => 150
        }
      end
    end

    trait :with_responses do
      after(:create) do |version|
        create_list(:llm_response, 5, prompt_version: version)
      end
    end
  end
end

