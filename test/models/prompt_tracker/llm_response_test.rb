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
require "test_helper"

module PromptTracker
  class LlmResponseTest < ActiveSupport::TestCase
    # Setup
    def setup
      @prompt = Prompt.create!(
        name: "test_prompt",
        description: "A test prompt"
      )

      @version = @prompt.prompt_versions.create!(
        template: "Hello {{name}}",
        status: "active",
        source: "file"
      )

      @valid_attributes = {
        prompt_version: @version,
        rendered_prompt: "Hello John",
        variables_used: { "name" => "John" },
        provider: "openai",
        model: "gpt-4",
        status: "pending"
      }
    end

    # Validation Tests

    test "should be valid with valid attributes" do
      response = LlmResponse.new(@valid_attributes)
      assert response.valid?, "LlmResponse should be valid with valid attributes"
    end

    test "should require rendered_prompt" do
      response = LlmResponse.new(@valid_attributes.except(:rendered_prompt))
      assert_not response.valid?
      assert_includes response.errors[:rendered_prompt], "can't be blank"
    end

    test "should require provider" do
      response = LlmResponse.new(@valid_attributes.except(:provider))
      assert_not response.valid?
      assert_includes response.errors[:provider], "can't be blank"
    end

    test "should require model" do
      response = LlmResponse.new(@valid_attributes.except(:model))
      assert_not response.valid?
      assert_includes response.errors[:model], "can't be blank"
    end

    test "should require valid status" do
      LlmResponse::STATUSES.each do |status|
        response = LlmResponse.new(@valid_attributes.merge(status: status))
        assert response.valid?, "Status '#{status}' should be valid"
      end

      response = LlmResponse.new(@valid_attributes.merge(status: "invalid"))
      assert_not response.valid?
      assert_includes response.errors[:status], "is not included in the list"
    end

    test "should validate response_time_ms is non-negative integer" do
      response = LlmResponse.new(@valid_attributes.merge(response_time_ms: 1000))
      assert response.valid?

      response = LlmResponse.new(@valid_attributes.merge(response_time_ms: -1))
      assert_not response.valid?
    end

    test "should validate tokens are non-negative integers" do
      response = LlmResponse.new(@valid_attributes.merge(
        tokens_prompt: 10,
        tokens_completion: 5,
        tokens_total: 15
      ))
      assert response.valid?

      response = LlmResponse.new(@valid_attributes.merge(tokens_total: -1))
      assert_not response.valid?
    end

    test "should validate cost_usd is non-negative" do
      response = LlmResponse.new(@valid_attributes.merge(cost_usd: 0.001))
      assert response.valid?

      response = LlmResponse.new(@valid_attributes.merge(cost_usd: -0.001))
      assert_not response.valid?
    end

    test "should validate variables_used is a hash" do
      response = LlmResponse.new(@valid_attributes.merge(variables_used: {}))
      assert response.valid?

      response = LlmResponse.new(@valid_attributes.merge(variables_used: "not a hash"))
      assert_not response.valid?
      assert_includes response.errors[:variables_used], "must be a hash"
    end

    test "should validate response_metadata is a hash" do
      response = LlmResponse.new(@valid_attributes.merge(response_metadata: {}))
      assert response.valid?

      response = LlmResponse.new(@valid_attributes.merge(response_metadata: "not a hash"))
      assert_not response.valid?
      assert_includes response.errors[:response_metadata], "must be a hash"
    end

    test "should validate context is a hash" do
      response = LlmResponse.new(@valid_attributes.merge(context: {}))
      assert response.valid?

      response = LlmResponse.new(@valid_attributes.merge(context: "not a hash"))
      assert_not response.valid?
      assert_includes response.errors[:context], "must be a hash"
    end

    # Association Tests

    test "should belong to prompt_version" do
      response = LlmResponse.create!(@valid_attributes)
      assert_equal @version, response.prompt_version
    end

    test "should have access to prompt through prompt_version" do
      response = LlmResponse.create!(@valid_attributes)
      assert_equal @prompt, response.prompt
    end

    # Scope Tests

    test "successful scope should return only successful responses" do
      successful = LlmResponse.create!(@valid_attributes.merge(status: "success"))
      failed = LlmResponse.create!(@valid_attributes.merge(status: "error"))

      successful_responses = LlmResponse.successful
      assert_includes successful_responses, successful
      assert_not_includes successful_responses, failed
    end

    test "failed scope should return error and timeout responses" do
      successful = LlmResponse.create!(@valid_attributes.merge(status: "success"))
      error = LlmResponse.create!(@valid_attributes.merge(status: "error"))
      timeout = LlmResponse.create!(@valid_attributes.merge(status: "timeout"))

      failed_responses = LlmResponse.failed
      assert_includes failed_responses, error
      assert_includes failed_responses, timeout
      assert_not_includes failed_responses, successful
    end

    test "for_provider scope should filter by provider" do
      openai = LlmResponse.create!(@valid_attributes.merge(provider: "openai"))
      anthropic = LlmResponse.create!(@valid_attributes.merge(provider: "anthropic"))

      openai_responses = LlmResponse.for_provider("openai")
      assert_includes openai_responses, openai
      assert_not_includes openai_responses, anthropic
    end

    test "for_model scope should filter by model" do
      gpt4 = LlmResponse.create!(@valid_attributes.merge(model: "gpt-4"))
      gpt35 = LlmResponse.create!(@valid_attributes.merge(model: "gpt-3.5-turbo"))

      gpt4_responses = LlmResponse.for_model("gpt-4")
      assert_includes gpt4_responses, gpt4
      assert_not_includes gpt4_responses, gpt35
    end

    test "for_user scope should filter by user_id" do
      user1 = LlmResponse.create!(@valid_attributes.merge(user_id: "user1"))
      user2 = LlmResponse.create!(@valid_attributes.merge(user_id: "user2"))

      user1_responses = LlmResponse.for_user("user1")
      assert_includes user1_responses, user1
      assert_not_includes user1_responses, user2
    end

    test "in_environment scope should filter by environment" do
      prod = LlmResponse.create!(@valid_attributes.merge(environment: "production"))
      staging = LlmResponse.create!(@valid_attributes.merge(environment: "staging"))

      prod_responses = LlmResponse.in_environment("production")
      assert_includes prod_responses, prod
      assert_not_includes prod_responses, staging
    end

    test "recent scope should return responses from last 24 hours" do
      recent = LlmResponse.create!(@valid_attributes)
      old = LlmResponse.create!(@valid_attributes.merge(created_at: 2.days.ago))

      recent_responses = LlmResponse.recent
      assert_includes recent_responses, recent
      assert_not_includes recent_responses, old
    end

    # mark_success! Tests

    test "mark_success! should update status and metrics" do
      response = LlmResponse.create!(@valid_attributes)

      response.mark_success!(
        response_text: "Hello there!",
        response_time_ms: 1200,
        tokens_prompt: 10,
        tokens_completion: 5,
        tokens_total: 15,
        cost_usd: 0.00045,
        response_metadata: { "finish_reason" => "stop" }
      )

      response.reload
      assert_equal "success", response.status
      assert_equal "Hello there!", response.response_text
      assert_equal 1200, response.response_time_ms
      assert_equal 10, response.tokens_prompt
      assert_equal 5, response.tokens_completion
      assert_equal 15, response.tokens_total
      assert_equal 0.00045, response.cost_usd
      assert_equal({ "finish_reason" => "stop" }, response.response_metadata)
    end

    # mark_error! Tests

    test "mark_error! should update status and error details" do
      response = LlmResponse.create!(@valid_attributes)

      response.mark_error!(
        error_type: "OpenAI::RateLimitError",
        error_message: "Rate limit exceeded",
        response_time_ms: 500
      )

      response.reload
      assert_equal "error", response.status
      assert_equal "OpenAI::RateLimitError", response.error_type
      assert_equal "Rate limit exceeded", response.error_message
      assert_equal 500, response.response_time_ms
    end

    # mark_timeout! Tests

    test "mark_timeout! should update status and timeout details" do
      response = LlmResponse.create!(@valid_attributes)

      response.mark_timeout!(
        response_time_ms: 30000,
        error_message: "Request timed out after 30s"
      )

      response.reload
      assert_equal "timeout", response.status
      assert_equal "Timeout", response.error_type
      assert_equal "Request timed out after 30s", response.error_message
      assert_equal 30000, response.response_time_ms
    end

    # Status Check Methods

    test "success? should return true for successful responses" do
      response = LlmResponse.create!(@valid_attributes.merge(status: "success"))
      assert response.success?
    end

    test "failed? should return true for error and timeout responses" do
      error = LlmResponse.create!(@valid_attributes.merge(status: "error"))
      timeout = LlmResponse.create!(@valid_attributes.merge(status: "timeout"))

      assert error.failed?
      assert timeout.failed?
    end

    test "pending? should return true for pending responses" do
      response = LlmResponse.create!(@valid_attributes.merge(status: "pending"))
      assert response.pending?
    end

    # Metric Methods

    test "cost_per_token should calculate correctly" do
      response = LlmResponse.create!(@valid_attributes.merge(
        cost_usd: 0.00015,
        tokens_total: 15
      ))

      assert_in_delta 0.00001, response.cost_per_token, 0.000001
    end

    test "cost_per_token should return nil when tokens_total is zero" do
      response = LlmResponse.create!(@valid_attributes.merge(
        cost_usd: 0.00015,
        tokens_total: 0
      ))

      assert_nil response.cost_per_token
    end

    test "cost_per_token should return nil when cost_usd is nil" do
      response = LlmResponse.create!(@valid_attributes.merge(
        cost_usd: nil,
        tokens_total: 15
      ))

      assert_nil response.cost_per_token
    end

    # Summary Method

    test "summary should return success summary" do
      response = LlmResponse.create!(@valid_attributes.merge(
        status: "success",
        response_time_ms: 1200,
        tokens_total: 15,
        cost_usd: 0.00045
      ))

      assert_equal "Success: 1200ms, 15 tokens, $0.00045", response.summary
    end

    test "summary should return error summary" do
      response = LlmResponse.create!(@valid_attributes.merge(
        status: "error",
        error_type: "RateLimitError",
        error_message: "Rate limit exceeded"
      ))

      assert_equal "Failed: RateLimitError - Rate limit exceeded", response.summary
    end

    test "summary should return pending summary" do
      response = LlmResponse.create!(@valid_attributes)
      assert_equal "Pending", response.summary
    end
  end
end

