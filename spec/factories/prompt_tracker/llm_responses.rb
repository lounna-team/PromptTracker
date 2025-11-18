# frozen_string_literal: true

# == Schema Information
#
# Table name: prompt_tracker_llm_responses
#
#  ab_test_id        :bigint
#  ab_variant        :string
#  context           :jsonb
#  cost_usd          :decimal(10, 6)
#  created_at        :datetime         not null
#  environment       :string
#  error_message     :text
#  error_type        :string
#  id                :bigint           not null, primary key
#  model             :string           not null
#  prompt_version_id :bigint           not null
#  provider          :string           not null
#  rendered_prompt   :text             not null
#  response_metadata :jsonb
#  response_text     :text
#  response_time_ms  :integer
#  session_id        :string
#  status            :string           default("pending"), not null
#  tokens_completion :integer
#  tokens_prompt     :integer
#  tokens_total      :integer
#  updated_at        :datetime         not null
#  user_id           :string
#  variables_used    :jsonb
#
FactoryBot.define do
  factory :llm_response, class: "PromptTracker::LlmResponse" do
    association :prompt_version, factory: :prompt_version
    rendered_prompt { "Hello John, how can I help you today?" }
    variables_used { { "name" => "John" } }
    provider { "openai" }
    model { "gpt-4" }
    status { "success" }
    response_text { "Hi! I'm here to help. What can I do for you?" }
    response_time_ms { 1200 }
    tokens_prompt { 10 }
    tokens_completion { 12 }
    tokens_total { 22 }
    cost_usd { 0.00066 }
    environment { "test" }

    trait :pending do
      status { "pending" }
      response_text { nil }
      response_time_ms { nil }
      tokens_total { nil }
      cost_usd { nil }
    end

    trait :error do
      status { "error" }
      response_text { nil }
      error_type { "APIError" }
      error_message { "API request failed" }
      response_time_ms { 500 }
    end

    trait :timeout do
      status { "timeout" }
      response_text { nil }
      error_type { "Timeout::Error" }
      error_message { "Request timed out after 30s" }
      response_time_ms { 30000 }
    end

    trait :with_user do
      user_id { "user_#{rand(1000)}" }
      session_id { "session_#{rand(1000)}" }
    end

    trait :with_evaluations do
      after(:create) do |response|
        create_list(:evaluation, 3, llm_response: response)
      end
    end

    trait :in_ab_test do
      association :ab_test, factory: :ab_test
      ab_variant { "A" }
    end
  end
end
