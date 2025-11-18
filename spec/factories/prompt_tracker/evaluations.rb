# frozen_string_literal: true

# == Schema Information
#
# Table name: prompt_tracker_evaluations
#
#  created_at      :datetime         not null
#  criteria_scores :jsonb
#  evaluator_id    :string
#  evaluator_type  :string           not null
#  feedback        :text
#  id              :bigint           not null, primary key
#  llm_response_id :bigint           not null
#  metadata        :jsonb
#  score           :decimal(10, 2)   not null
#  score_max       :decimal(10, 2)   default(5.0)
#  score_min       :decimal(10, 2)   default(0.0)
#  updated_at      :datetime         not null
#
FactoryBot.define do
  factory :evaluation, class: "PromptTracker::Evaluation" do
    association :llm_response, factory: :llm_response
    score { 4.5 }
    score_min { 0 }
    score_max { 5 }
    evaluator_type { "automated" }
    evaluator_id { "length_evaluator" }
    feedback { nil }
    criteria_scores { {} }
    metadata { {} }

    trait :human do
      evaluator_type { "human" }
      evaluator_id { "reviewer@example.com" }
      feedback { "Good response, clear and helpful" }
      criteria_scores do
        {
          "helpfulness" => 5,
          "tone" => 4,
          "accuracy" => 4.5
        }
      end
    end

    trait :automated do
      evaluator_type { "automated" }
      evaluator_id { "keyword_evaluator" }
      score { 85 }
      score_min { 0 }
      score_max { 100 }
    end

    trait :llm_judge do
      evaluator_type { "llm_judge" }
      evaluator_id { "gpt-4" }
      feedback { "The response is accurate and well-structured." }
      metadata do
        {
          "model" => "gpt-4",
          "prompt_used" => "Evaluate this response..."
        }
      end
    end

    trait :passing do
      score { 4.5 }
      score_min { 0 }
      score_max { 5 }
    end

    trait :failing do
      score { 2.0 }
      score_min { 0 }
      score_max { 5 }
    end
  end
end

