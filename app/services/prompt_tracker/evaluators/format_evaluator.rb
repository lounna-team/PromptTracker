# frozen_string_literal: true

require "json"

module PromptTracker
  module Evaluators
    # Evaluates response based on format requirements.
    #
    # Checks if the response matches expected formats like JSON, markdown, etc.
    #
    # @example Validate JSON format
    #   evaluator = FormatEvaluator.new(llm_response, {
    #     format: :json,
    #     required_keys: ["name", "email"]
    #   })
    #   evaluation = evaluator.evaluate
    #
    # @example Validate markdown format
    #   evaluator = FormatEvaluator.new(llm_response, {
    #     format: :markdown,
    #     require_headers: true
    #   })
    #
    class FormatEvaluator < BaseEvaluator
      # Supported formats
      FORMATS = %i[json markdown plain_text].freeze

      # Default configuration
      DEFAULT_CONFIG = {
        format: :plain_text,     # Expected format
        required_keys: [],       # For JSON: required top-level keys
        require_headers: false,  # For markdown: require headers
        max_parse_errors: 0      # Maximum allowed parse errors
      }.freeze

      def initialize(llm_response, config = {})
        super(llm_response, DEFAULT_CONFIG.merge(config))
        validate_config!
      end

      def evaluate_score
        case config[:format]
        when :json
          evaluate_json_format
        when :markdown
          evaluate_markdown_format
        when :plain_text
          evaluate_plain_text_format
        else
          50 # Unknown format
        end
      end

      def evaluate_criteria
        case config[:format]
        when :json
          json_criteria
        when :markdown
          markdown_criteria
        when :plain_text
          plain_text_criteria
        else
          {}
        end
      end

      def generate_feedback
        case config[:format]
        when :json
          json_feedback
        when :markdown
          markdown_feedback
        when :plain_text
          plain_text_feedback
        else
          "Unknown format: #{config[:format]}"
        end
      end

      def evaluator_id
        "format_evaluator_v1"
      end

      def metadata
        super.merge(
          format: config[:format],
          format_valid: format_valid?
        )
      end

      private

      def validate_config!
        unless FORMATS.include?(config[:format])
          raise ArgumentError, "Invalid format: #{config[:format]}. Must be one of: #{FORMATS.join(', ')}"
        end
      end

      def format_valid?
        case config[:format]
        when :json
          json_valid?
        when :markdown
          markdown_valid?
        when :plain_text
          true # Plain text is always valid
        else
          false
        end
      end

      # JSON format evaluation
      def evaluate_json_format
        return 0 unless json_valid?

        parsed = parse_json
        return 100 if config[:required_keys].empty?

        # Check required keys
        missing_keys = config[:required_keys] - parsed.keys
        present_keys = config[:required_keys].length - missing_keys.length

        ((present_keys.to_f / config[:required_keys].length) * 100).round
      end

      def json_valid?
        parse_json
        true
      rescue JSON::ParserError
        false
      end

      def parse_json
        JSON.parse(response_text)
      end

      def json_criteria
        valid = json_valid?
        criteria = { "valid_json" => valid ? 100 : 0 }

        if valid && config[:required_keys].any?
          parsed = parse_json
          config[:required_keys].each do |key|
            criteria["has_key_#{key}"] = parsed.key?(key) ? 100 : 0
          end
        end

        criteria
      end

      def json_feedback
        return "Invalid JSON format" unless json_valid?

        if config[:required_keys].empty?
          "Valid JSON format"
        else
          parsed = parse_json
          missing = config[:required_keys] - parsed.keys

          if missing.empty?
            "Valid JSON with all required keys"
          else
            "Valid JSON but missing keys: #{missing.join(', ')}"
          end
        end
      end

      # Markdown format evaluation
      def evaluate_markdown_format
        score = 100

        if config[:require_headers] && !has_markdown_headers?
          score -= 50
        end

        score
      end

      def markdown_valid?
        # Basic markdown validation: check for common markdown patterns
        response_text.match?(/[#*_\[\]`]/) || response_text.length > 0
      end

      def has_markdown_headers?
        response_text.match?(/^[#]{1,6}\s+.+/)
      end

      def markdown_criteria
        {
          "has_headers" => has_markdown_headers? ? 100 : 0,
          "has_markdown_syntax" => response_text.match?(/[#*_\[\]`]/) ? 100 : 0
        }
      end

      def markdown_feedback
        parts = []

        if config[:require_headers] && !has_markdown_headers?
          parts << "Missing markdown headers"
        end

        parts.empty? ? "Valid markdown format" : parts.join(". ")
      end

      # Plain text format evaluation
      def evaluate_plain_text_format
        response_text.length > 0 ? 100 : 0
      end

      def plain_text_criteria
        {
          "has_content" => response_text.length > 0 ? 100 : 0
        }
      end

      def plain_text_feedback
        response_text.length > 0 ? "Valid plain text" : "Empty response"
      end
    end
  end
end
