# frozen_string_literal: true

# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "🌱 Seeding PromptTracker database..."

# Clean up existing data
puts "  Cleaning up existing data..."
PromptTracker::Evaluation.delete_all
PromptTracker::LlmResponse.delete_all
PromptTracker::PromptVersion.delete_all
PromptTracker::Prompt.delete_all

# ============================================================================
# 1. Customer Support Prompts
# ============================================================================

puts "  Creating customer support prompts..."

support_greeting = PromptTracker::Prompt.create!(
  name: "customer_support_greeting",
  description: "Initial greeting for customer support interactions",
  category: "support",
  tags: ["customer-facing", "greeting", "high-priority"],
  created_by: "support-team@example.com"
)

# Version 1 - Original
support_greeting_v1 = support_greeting.prompt_versions.create!(
  template: "Hello {{customer_name}}! Thank you for contacting support. How can I help you with {{issue_category}} today?",
  status: "deprecated",
  source: "file",
  variables_schema: [
    { "name" => "customer_name", "type" => "string", "required" => true },
    { "name" => "issue_category", "type" => "string", "required" => false }
  ],
  model_config: { "temperature" => 0.7, "max_tokens" => 150 },
  notes: "Original version - too formal",
  created_by: "john@example.com"
)

# Version 2 - More casual
support_greeting_v2 = support_greeting.prompt_versions.create!(
  template: "Hi {{customer_name}}! 👋 Thanks for reaching out. What can I help you with today?",
  status: "deprecated",
  source: "web_ui",
  variables_schema: [
    { "name" => "customer_name", "type" => "string", "required" => true }
  ],
  model_config: { "temperature" => 0.8, "max_tokens" => 100 },
  notes: "Tested in web UI - more casual tone",
  created_by: "sarah@example.com"
)

# Version 3 - Current active version
support_greeting_v3 = support_greeting.prompt_versions.create!(
  template: "Hi {{customer_name}}! Thanks for contacting us. I'm here to help with your {{issue_category}} question. What's going on?",
  status: "active",
  source: "file",
  variables_schema: [
    { "name" => "customer_name", "type" => "string", "required" => true },
    { "name" => "issue_category", "type" => "string", "required" => true }
  ],
  model_config: { "temperature" => 0.7, "max_tokens" => 120 },
  notes: "Best performing version - friendly but professional",
  created_by: "john@example.com"
)

# ============================================================================
# 2. Email Generation Prompts
# ============================================================================

puts "  Creating email generation prompts..."

email_summary = PromptTracker::Prompt.create!(
  name: "email_summary_generator",
  description: "Generates concise summaries of long email threads",
  category: "email",
  tags: ["productivity", "summarization"],
  created_by: "product-team@example.com"
)

email_summary_v1 = email_summary.prompt_versions.create!(
  template: "Summarize the following email thread in 2-3 sentences:\n\n{{email_thread}}",
  status: "active",
  source: "file",
  variables_schema: [
    { "name" => "email_thread", "type" => "string", "required" => true }
  ],
  model_config: { "temperature" => 0.3, "max_tokens" => 200 },
  created_by: "alice@example.com"
)

# ============================================================================
# 3. Code Review Prompts
# ============================================================================

puts "  Creating code review prompts..."

code_review = PromptTracker::Prompt.create!(
  name: "code_review_assistant",
  description: "Provides constructive code review feedback",
  category: "development",
  tags: ["code-quality", "engineering"],
  created_by: "engineering@example.com"
)

code_review_v1 = code_review.prompt_versions.create!(
  template: <<~TEMPLATE,
    Review the following {{language}} code and provide constructive feedback:

    ```{{language}}
    {{code}}
    ```

    Focus on:
    - Code quality and readability
    - Potential bugs or edge cases
    - Performance considerations
    - Best practices

    Be constructive and specific.
  TEMPLATE
  status: "active",
  source: "file",
  variables_schema: [
    { "name" => "language", "type" => "string", "required" => true },
    { "name" => "code", "type" => "string", "required" => true }
  ],
  model_config: { "temperature" => 0.4, "max_tokens" => 500 },
  created_by: "bob@example.com"
)

# ============================================================================
# 4. Create Sample LLM Responses
# ============================================================================

puts "  Creating sample LLM responses..."

# Successful responses for support greeting v3
5.times do |i|
  response = support_greeting_v3.llm_responses.create!(
    rendered_prompt: "Hi John! Thanks for contacting us. I'm here to help with your billing question. What's going on?",
    variables_used: { "customer_name" => "John", "issue_category" => "billing" },
    provider: "openai",
    model: "gpt-4",
    user_id: "user_#{i + 1}",
    session_id: "session_#{i + 1}",
    environment: "production"
  )

  response.mark_success!(
    response_text: "I'd be happy to help you with your billing question. Could you please provide more details about the specific issue you're experiencing?",
    response_time_ms: rand(800..1500),
    tokens_prompt: 25,
    tokens_completion: rand(20..30),
    tokens_total: rand(45..55),
    cost_usd: rand(0.0008..0.0015).round(6),
    response_metadata: { "finish_reason" => "stop", "model" => "gpt-4-0125-preview" }
  )
end

# Failed response
failed_response = support_greeting_v3.llm_responses.create!(
  rendered_prompt: "Hi Jane! Thanks for contacting us. I'm here to help with your technical question. What's going on?",
  variables_used: { "customer_name" => "Jane", "issue_category" => "technical" },
  provider: "openai",
  model: "gpt-4",
  user_id: "user_6",
  session_id: "session_6",
  environment: "production"
)

failed_response.mark_error!(
  error_type: "OpenAI::RateLimitError",
  error_message: "Rate limit exceeded. Please try again in 20 seconds.",
  response_time_ms: 450
)

# Timeout response
timeout_response = support_greeting_v3.llm_responses.create!(
  rendered_prompt: "Hi Bob! Thanks for contacting us. I'm here to help with your account question. What's going on?",
  variables_used: { "customer_name" => "Bob", "issue_category" => "account" },
  provider: "anthropic",
  model: "claude-3-opus",
  user_id: "user_7",
  session_id: "session_7",
  environment: "production"
)

timeout_response.mark_timeout!(
  response_time_ms: 30000,
  error_message: "Request timed out after 30 seconds"
)

# Responses for older versions (v1 and v2)
2.times do |i|
  response = support_greeting_v1.llm_responses.create!(
    rendered_prompt: "Hello Sarah! Thank you for contacting support. How can I help you with billing today?",
    variables_used: { "customer_name" => "Sarah", "issue_category" => "billing" },
    provider: "openai",
    model: "gpt-3.5-turbo",
    user_id: "user_old_#{i + 1}",
    environment: "production"
  )

  response.mark_success!(
    response_text: "I would be pleased to assist you with your billing inquiry.",
    response_time_ms: rand(600..1000),
    tokens_total: rand(30..40),
    cost_usd: rand(0.0003..0.0006).round(6)
  )
end

# Email summary responses
3.times do |i|
  response = email_summary_v1.llm_responses.create!(
    rendered_prompt: "Summarize the following email thread in 2-3 sentences:\n\nLong email thread here...",
    variables_used: { "email_thread" => "Long email thread here..." },
    provider: "openai",
    model: "gpt-4",
    user_id: "user_email_#{i + 1}",
    environment: "production"
  )

  response.mark_success!(
    response_text: "The email thread discusses the upcoming product launch. The team agrees on a March 15th release date. Action items include finalizing the marketing materials and scheduling a press release.",
    response_time_ms: rand(1000..2000),
    tokens_total: rand(60..80),
    cost_usd: rand(0.0015..0.0025).round(6)
  )
end

# ============================================================================
# 5. Create Sample Evaluations
# ============================================================================

puts "  Creating sample evaluations..."

# Get successful responses
successful_responses = PromptTracker::LlmResponse.successful.limit(5)

successful_responses.each_with_index do |response, i|
  # Human evaluation
  response.evaluations.create!(
    score: rand(3.5..5.0).round(1),
    score_max: 5,
    criteria_scores: {
      "helpfulness" => rand(4..5),
      "tone" => rand(3..5),
      "accuracy" => rand(4..5),
      "conciseness" => rand(3..5)
    },
    evaluator_type: "human",
    evaluator_id: "manager@example.com",
    feedback: ["Great response!", "Very helpful", "Could be more concise", "Perfect tone"][i % 4]
  )

  # Automated evaluation
  response.evaluations.create!(
    score: rand(70..95),
    score_max: 100,
    evaluator_type: "automated",
    evaluator_id: "sentiment_analyzer_v1",
    metadata: {
      "confidence" => rand(0.8..0.99).round(2),
      "processing_time_ms" => rand(50..200)
    }
  )

  # LLM judge evaluation (for some responses)
  if i.even?
    response.evaluations.create!(
      score: rand(3.5..4.8).round(1),
      score_max: 5,
      criteria_scores: {
        "helpfulness" => rand(4..5),
        "professionalism" => rand(4..5)
      },
      evaluator_type: "llm_judge",
      evaluator_id: "gpt-4",
      feedback: "The response is helpful and maintains a professional yet friendly tone.",
      metadata: {
        "reasoning" => "Good balance of professionalism and warmth",
        "evaluation_cost_usd" => 0.0002
      }
    )
  end
end

# ============================================================================
# Summary
# ============================================================================

puts "\n✅ Seeding complete!"
puts "\nCreated:"
puts "  - #{PromptTracker::Prompt.count} prompts"
puts "  - #{PromptTracker::PromptVersion.count} prompt versions"
puts "  - #{PromptTracker::LlmResponse.count} LLM responses"
puts "    - #{PromptTracker::LlmResponse.successful.count} successful"
puts "    - #{PromptTracker::LlmResponse.failed.count} failed"
puts "  - #{PromptTracker::Evaluation.count} evaluations"
puts "    - #{PromptTracker::Evaluation.by_humans.count} human"
puts "    - #{PromptTracker::Evaluation.automated.count} automated"
puts "    - #{PromptTracker::Evaluation.by_llm_judge.count} LLM judge"
puts "\nTotal cost: $#{PromptTracker::LlmResponse.sum(:cost_usd).round(4)}"
puts "Average response time: #{PromptTracker::LlmResponse.successful.average(:response_time_ms).to_i}ms"
puts "\n🎉 Ready to explore!"

