# frozen_string_literal: true

module PromptTracker
  # Extracts standardized data from different LLM provider response formats.
  #
  # Different LLM providers return responses in different formats. This service
  # provides a unified interface to extract:
  # - Response text
  # - Token counts (prompt, completion, total)
  # - Metadata
  #
  # @example Extract from OpenAI response
  #   response = {
  #     "choices" => [{ "message" => { "content" => "Hello!" } }],
  #     "usage" => { "prompt_tokens" => 10, "completion_tokens" => 5, "total_tokens" => 15 }
  #   }
  #   extractor = ResponseExtractor.new(response)
  #   extractor.text  # => "Hello!"
  #   extractor.tokens_prompt  # => 10
  #
  # @example Extract from Anthropic response
  #   response = {
  #     "content" => [{ "text" => "Hello!" }],
  #     "usage" => { "input_tokens" => 10, "output_tokens" => 5 }
  #   }
  #   extractor = ResponseExtractor.new(response)
  #   extractor.text  # => "Hello!"
  #
  # @example Extract from plain string
  #   extractor = ResponseExtractor.new("Hello!")
  #   extractor.text  # => "Hello!"
  #
  class ResponseExtractor
    attr_reader :response

    # Initialize a new response extractor
    #
    # @param response [Hash, String, Object] the LLM response object
    def initialize(response)
      @response = response
    end

    # Extract the response text
    #
    # @return [String, nil] the response text or nil if not found
    def text
      return response if response.is_a?(String)
      return nil unless response.respond_to?(:[])

      # Try different common formats
      extract_openai_text ||
        extract_anthropic_text ||
        extract_google_text ||
        extract_cohere_text ||
        extract_generic_text
    end

    # Extract prompt/input token count
    #
    # @return [Integer, nil] number of prompt tokens or nil if not available
    def tokens_prompt
      return nil unless response.respond_to?(:[])

      # Try different common formats
      dig_value("usage", "prompt_tokens") ||
        dig_value("usage", "input_tokens") ||
        dig_value("usage", "promptTokenCount") ||
        dig_value("meta", "billed_units", "input_tokens")
    end

    # Extract completion/output token count
    #
    # @return [Integer, nil] number of completion tokens or nil if not available
    def tokens_completion
      return nil unless response.respond_to?(:[])

      # Try different common formats
      dig_value("usage", "completion_tokens") ||
        dig_value("usage", "output_tokens") ||
        dig_value("usage", "candidatesTokenCount") ||
        dig_value("meta", "billed_units", "output_tokens")
    end

    # Extract total token count
    #
    # @return [Integer, nil] total tokens or nil if not available
    def tokens_total
      return nil unless response.respond_to?(:[])

      # Try explicit total first
      total = dig_value("usage", "total_tokens") ||
              dig_value("usage", "totalTokenCount")

      return total if total

      # Calculate from prompt + completion if available
      prompt = tokens_prompt
      completion = tokens_completion
      return nil if prompt.nil? || completion.nil?

      prompt + completion
    end

    # Extract metadata (everything except the main text and token counts)
    #
    # @return [Hash] metadata hash
    def metadata
      return {} unless response.respond_to?(:[])

      meta = {}

      # Add model info if available
      meta[:model] = response["model"] if response["model"]
      meta[:id] = response["id"] if response["id"]

      # Add finish reason if available
      finish_reason = dig_value("choices", 0, "finish_reason") ||
                      dig_value("stop_reason")
      meta[:finish_reason] = finish_reason if finish_reason

      # Add any provider-specific metadata
      if response.respond_to?(:except)
        provider_metadata = response.except("choices", "content", "text", "usage", "model", "id")
        meta[:provider_metadata] = provider_metadata if provider_metadata.present?
      end

      meta
    end

    # Extract all data at once
    #
    # @return [Hash] hash with :text, :tokens_prompt, :tokens_completion, :tokens_total, :metadata
    def extract_all
      {
        text: text,
        tokens_prompt: tokens_prompt,
        tokens_completion: tokens_completion,
        tokens_total: tokens_total,
        metadata: metadata
      }
    end

    private

    # Extract text from OpenAI format
    # { "choices" => [{ "message" => { "content" => "..." } }] }
    def extract_openai_text
      dig_value("choices", 0, "message", "content") ||
        dig_value("choices", 0, "text")
    end

    # Extract text from Anthropic format
    # { "content" => [{ "text" => "..." }] }
    def extract_anthropic_text
      dig_value("content", 0, "text") ||
        dig_value("completion")
    end

    # Extract text from Google format
    # { "candidates" => [{ "content" => { "parts" => [{ "text" => "..." }] } }] }
    def extract_google_text
      dig_value("candidates", 0, "content", "parts", 0, "text")
    end

    # Extract text from Cohere format
    # { "generations" => [{ "text" => "..." }] }
    def extract_cohere_text
      dig_value("generations", 0, "text") ||
        dig_value("text")
    end

    # Extract text from generic format
    # Try common keys: "text", "response", "output", "result"
    def extract_generic_text
      response["text"] ||
        response["response"] ||
        response["output"] ||
        response["result"]
    end

    # Safely dig into nested hash/array structure
    #
    # @param keys [Array] keys to dig through
    # @return [Object, nil] the value or nil if not found
    def dig_value(*keys)
      keys.reduce(response) do |obj, key|
        return nil unless obj.respond_to?(:[])
        obj[key]
      end
    rescue StandardError
      nil
    end
  end
end
