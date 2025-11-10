# frozen_string_literal: true

require "test_helper"

module PromptTracker
  class ResponseExtractorTest < ActiveSupport::TestCase
    # OpenAI Format Tests

    test "should extract text from OpenAI chat format" do
      response = {
        "choices" => [
          { "message" => { "content" => "Hello, how can I help you?" } }
        ]
      }
      extractor = ResponseExtractor.new(response)
      assert_equal "Hello, how can I help you?", extractor.text
    end

    test "should extract tokens from OpenAI format" do
      response = {
        "usage" => {
          "prompt_tokens" => 10,
          "completion_tokens" => 20,
          "total_tokens" => 30
        }
      }
      extractor = ResponseExtractor.new(response)
      assert_equal 10, extractor.tokens_prompt
      assert_equal 20, extractor.tokens_completion
      assert_equal 30, extractor.tokens_total
    end

    test "should extract metadata from OpenAI format" do
      response = {
        "id" => "chatcmpl-123",
        "model" => "gpt-4",
        "choices" => [
          { "finish_reason" => "stop" }
        ]
      }
      extractor = ResponseExtractor.new(response)
      metadata = extractor.metadata

      assert_equal "chatcmpl-123", metadata[:id]
      assert_equal "gpt-4", metadata[:model]
      assert_equal "stop", metadata[:finish_reason]
    end

    # Anthropic Format Tests

    test "should extract text from Anthropic format" do
      response = {
        "content" => [
          { "text" => "I'm Claude, how can I assist you?" }
        ]
      }
      extractor = ResponseExtractor.new(response)
      assert_equal "I'm Claude, how can I assist you?", extractor.text
    end

    test "should extract tokens from Anthropic format" do
      response = {
        "usage" => {
          "input_tokens" => 15,
          "output_tokens" => 25
        }
      }
      extractor = ResponseExtractor.new(response)
      assert_equal 15, extractor.tokens_prompt
      assert_equal 25, extractor.tokens_completion
      assert_equal 40, extractor.tokens_total
    end

    test "should extract stop_reason from Anthropic format" do
      response = {
        "stop_reason" => "end_turn"
      }
      extractor = ResponseExtractor.new(response)
      assert_equal "end_turn", extractor.metadata[:finish_reason]
    end

    # Google Format Tests

    test "should extract text from Google Gemini format" do
      response = {
        "candidates" => [
          {
            "content" => {
              "parts" => [
                { "text" => "Hello from Gemini!" }
              ]
            }
          }
        ]
      }
      extractor = ResponseExtractor.new(response)
      assert_equal "Hello from Gemini!", extractor.text
    end

    # Cohere Format Tests

    test "should extract text from Cohere format" do
      response = {
        "generations" => [
          { "text" => "Hello from Cohere!" }
        ]
      }
      extractor = ResponseExtractor.new(response)
      assert_equal "Hello from Cohere!", extractor.text
    end

    test "should extract text from Cohere simple format" do
      response = { "text" => "Simple response" }
      extractor = ResponseExtractor.new(response)
      assert_equal "Simple response", extractor.text
    end

    # Generic Format Tests

    test "should extract text from generic response key" do
      response = { "response" => "Generic response" }
      extractor = ResponseExtractor.new(response)
      assert_equal "Generic response", extractor.text
    end

    test "should extract text from output key" do
      response = { "output" => "Output text" }
      extractor = ResponseExtractor.new(response)
      assert_equal "Output text", extractor.text
    end

    test "should extract text from result key" do
      response = { "result" => "Result text" }
      extractor = ResponseExtractor.new(response)
      assert_equal "Result text", extractor.text
    end

    # String Response Tests

    test "should handle plain string response" do
      extractor = ResponseExtractor.new("Plain string response")
      assert_equal "Plain string response", extractor.text
    end

    # Edge Cases

    test "should return nil for missing text" do
      response = { "some_key" => "value" }
      extractor = ResponseExtractor.new(response)
      assert_nil extractor.text
    end

    test "should return nil for nil response" do
      extractor = ResponseExtractor.new(nil)
      assert_nil extractor.text
      assert_nil extractor.tokens_prompt
      assert_nil extractor.tokens_completion
      assert_nil extractor.tokens_total
    end

    test "should return nil for empty hash" do
      extractor = ResponseExtractor.new({})
      assert_nil extractor.text
      assert_nil extractor.tokens_prompt
      assert_nil extractor.tokens_completion
    end

    test "should calculate total tokens from prompt and completion" do
      response = {
        "usage" => {
          "prompt_tokens" => 100,
          "completion_tokens" => 50
        }
      }
      extractor = ResponseExtractor.new(response)
      assert_equal 150, extractor.tokens_total
    end

    test "should return nil total tokens if prompt or completion missing" do
      response = {
        "usage" => {
          "prompt_tokens" => 100
        }
      }
      extractor = ResponseExtractor.new(response)
      assert_nil extractor.tokens_total
    end

    test "should prefer explicit total_tokens over calculation" do
      response = {
        "usage" => {
          "prompt_tokens" => 100,
          "completion_tokens" => 50,
          "total_tokens" => 200  # Different from sum
        }
      }
      extractor = ResponseExtractor.new(response)
      assert_equal 200, extractor.tokens_total
    end

    # extract_all Tests

    test "should extract all data at once" do
      response = {
        "choices" => [
          { "message" => { "content" => "Hello!" } }
        ],
        "usage" => {
          "prompt_tokens" => 10,
          "completion_tokens" => 5,
          "total_tokens" => 15
        },
        "model" => "gpt-4",
        "id" => "test-123"
      }
      extractor = ResponseExtractor.new(response)
      data = extractor.extract_all

      assert_equal "Hello!", data[:text]
      assert_equal 10, data[:tokens_prompt]
      assert_equal 5, data[:tokens_completion]
      assert_equal 15, data[:tokens_total]
      assert_equal "gpt-4", data[:metadata][:model]
      assert_equal "test-123", data[:metadata][:id]
    end

    test "should extract all data with missing fields" do
      response = { "text" => "Simple" }
      extractor = ResponseExtractor.new(response)
      data = extractor.extract_all

      assert_equal "Simple", data[:text]
      assert_nil data[:tokens_prompt]
      assert_nil data[:tokens_completion]
      assert_nil data[:tokens_total]
      assert_equal({}, data[:metadata])
    end

    # Metadata Tests

    test "should extract empty metadata for string response" do
      extractor = ResponseExtractor.new("string")
      assert_equal({}, extractor.metadata)
    end

    test "should extract empty metadata for nil response" do
      extractor = ResponseExtractor.new(nil)
      assert_equal({}, extractor.metadata)
    end

    test "should not include standard keys in provider_metadata" do
      response = {
        "choices" => [{ "message" => { "content" => "Hi" } }],
        "model" => "gpt-4",
        "custom_field" => "custom_value"
      }
      extractor = ResponseExtractor.new(response)
      metadata = extractor.metadata

      # Should have model but not in provider_metadata
      assert_equal "gpt-4", metadata[:model]
      # Custom field should be in provider_metadata
      assert_equal "custom_value", metadata[:provider_metadata]["custom_field"]
    end

    # Complex Nested Structure Tests

    test "should handle deeply nested OpenAI structure" do
      response = {
        "id" => "chatcmpl-abc123",
        "object" => "chat.completion",
        "created" => 1234567890,
        "model" => "gpt-4-0125-preview",
        "choices" => [
          {
            "index" => 0,
            "message" => {
              "role" => "assistant",
              "content" => "This is a test response."
            },
            "finish_reason" => "stop"
          }
        ],
        "usage" => {
          "prompt_tokens" => 25,
          "completion_tokens" => 10,
          "total_tokens" => 35
        }
      }
      extractor = ResponseExtractor.new(response)

      assert_equal "This is a test response.", extractor.text
      assert_equal 25, extractor.tokens_prompt
      assert_equal 10, extractor.tokens_completion
      assert_equal 35, extractor.tokens_total
      assert_equal "gpt-4-0125-preview", extractor.metadata[:model]
      assert_equal "stop", extractor.metadata[:finish_reason]
    end

    test "should handle Anthropic completion format" do
      response = {
        "completion" => "Legacy Anthropic response"
      }
      extractor = ResponseExtractor.new(response)
      assert_equal "Legacy Anthropic response", extractor.text
    end

    # Error Handling Tests

    test "should handle malformed response gracefully" do
      response = {
        "choices" => "not an array"
      }
      extractor = ResponseExtractor.new(response)
      assert_nil extractor.text
    end

    test "should handle response with nil values" do
      response = {
        "choices" => [nil],
        "usage" => nil
      }
      extractor = ResponseExtractor.new(response)
      assert_nil extractor.text
      assert_nil extractor.tokens_prompt
    end
  end
end

