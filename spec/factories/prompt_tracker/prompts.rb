# frozen_string_literal: true

FactoryBot.define do
  factory :prompt, class: "PromptTracker::Prompt" do
    sequence(:name) { |n| "test_prompt_#{n}" }
    description { "A test prompt for #{name}" }
    category { "test" }
    tags { %w[test automated] }
    created_by { "test@example.com" }
    archived_at { nil }

    trait :support do
      category { "support" }
      tags { %w[customer-facing support] }
    end

    trait :email do
      category { "email" }
      tags { %w[email automated] }
    end

    trait :archived do
      archived_at { 1.day.ago }
    end

    trait :with_versions do
      after(:create) do |prompt|
        create_list(:prompt_version, 3, prompt: prompt)
      end
    end

    trait :with_active_version do
      after(:create) do |prompt|
        create(:prompt_version, :active, prompt: prompt)
      end
    end
  end
end

