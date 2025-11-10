# frozen_string_literal: true

require "test_helper"

module PromptTracker
  module Evaluators
    class FormatEvaluatorTest < ActiveSupport::TestCase
      setup do
        @prompt = Prompt.create!(
          name: "test_prompt",
          description: "Test",
          category: "test"
        )

        @version = @prompt.prompt_versions.create!(
          template: "Test",
          status: "active",
          source: "api"
        )
      end

      def create_response(text)
        @version.llm_responses.create!(
          rendered_prompt: "Test",
          provider: "openai",
          model: "gpt-4",
          response_text: text,
          status: "success"
        )
      end

      # JSON format tests

      test "should score 100 for valid JSON" do
        response = create_response('{"name": "John", "age": 30}')
        evaluator = FormatEvaluator.new(response, { format: :json })

        assert_equal 100, evaluator.evaluate_score
      end

      test "should score 0 for invalid JSON" do
        response = create_response('not valid json')
        evaluator = FormatEvaluator.new(response, { format: :json })

        assert_equal 0, evaluator.evaluate_score
      end

      test "should validate required JSON keys" do
        response = create_response('{"name": "John", "email": "john@example.com"}')
        evaluator = FormatEvaluator.new(response, {
          format: :json,
          required_keys: ["name", "email"]
        })

        assert_equal 100, evaluator.evaluate_score
      end

      test "should score partial for missing JSON keys" do
        response = create_response('{"name": "John"}')
        evaluator = FormatEvaluator.new(response, {
          format: :json,
          required_keys: ["name", "email", "age"]
        })

        # 1 out of 3 keys = 33%
        assert_equal 33, evaluator.evaluate_score
      end

      test "should generate feedback for valid JSON" do
        response = create_response('{"test": true}')
        evaluator = FormatEvaluator.new(response, { format: :json })

        feedback = evaluator.generate_feedback
        assert_match(/valid json/i, feedback)
      end

      test "should generate feedback for invalid JSON" do
        response = create_response('invalid')
        evaluator = FormatEvaluator.new(response, { format: :json })

        feedback = evaluator.generate_feedback
        assert_match(/invalid json/i, feedback)
      end

      test "should generate feedback for missing JSON keys" do
        response = create_response('{"name": "John"}')
        evaluator = FormatEvaluator.new(response, {
          format: :json,
          required_keys: ["name", "email"]
        })

        feedback = evaluator.generate_feedback
        assert_match(/missing keys/i, feedback)
        assert_match(/email/i, feedback)
      end

      test "should evaluate JSON criteria" do
        response = create_response('{"name": "John"}')
        evaluator = FormatEvaluator.new(response, {
          format: :json,
          required_keys: ["name", "email"]
        })

        criteria = evaluator.evaluate_criteria
        assert_equal 100, criteria["valid_json"]
        assert_equal 100, criteria["has_key_name"]
        assert_equal 0, criteria["has_key_email"]
      end

      # Markdown format tests

      test "should score 100 for markdown with headers" do
        response = create_response("# Title\n\nSome content")
        evaluator = FormatEvaluator.new(response, {
          format: :markdown,
          require_headers: true
        })

        assert_equal 100, evaluator.evaluate_score
      end

      test "should score 50 for markdown without headers when required" do
        response = create_response("Just plain text")
        evaluator = FormatEvaluator.new(response, {
          format: :markdown,
          require_headers: true
        })

        assert_equal 50, evaluator.evaluate_score
      end

      test "should score 100 for markdown without headers when not required" do
        response = create_response("Just plain text")
        evaluator = FormatEvaluator.new(response, {
          format: :markdown,
          require_headers: false
        })

        assert_equal 100, evaluator.evaluate_score
      end

      test "should evaluate markdown criteria" do
        response = create_response("# Title\n\n**Bold** text")
        evaluator = FormatEvaluator.new(response, { format: :markdown })

        criteria = evaluator.evaluate_criteria
        assert_equal 100, criteria["has_headers"]
        assert_equal 100, criteria["has_markdown_syntax"]
      end

      # Plain text format tests

      test "should score 100 for non-empty plain text" do
        response = create_response("Any text here")
        evaluator = FormatEvaluator.new(response, { format: :plain_text })

        assert_equal 100, evaluator.evaluate_score
      end

      test "should score 0 for empty plain text" do
        response = create_response("")
        evaluator = FormatEvaluator.new(response, { format: :plain_text })

        assert_equal 0, evaluator.evaluate_score
      end

      # General tests

      test "should raise error for invalid format" do
        response = create_response("test")

        assert_raises(ArgumentError) do
          FormatEvaluator.new(response, { format: :invalid_format })
        end
      end

      test "should create evaluation record" do
        response = create_response('{"test": true}')
        evaluator = FormatEvaluator.new(response, { format: :json })

        evaluation = evaluator.evaluate

        assert evaluation.persisted?
        assert_equal "automated", evaluation.evaluator_type
        assert_equal "format_evaluator_v1", evaluation.evaluator_id
      end

      test "should include metadata" do
        response = create_response('{"test": true}')
        evaluator = FormatEvaluator.new(response, { format: :json })

        metadata = evaluator.metadata
        assert_equal :json, metadata[:format]
        assert_equal true, metadata[:format_valid]
      end

      test "should handle complex nested JSON" do
        json = '{"user": {"name": "John", "address": {"city": "NYC"}}}'
        response = create_response(json)
        evaluator = FormatEvaluator.new(response, {
          format: :json,
          required_keys: ["user"]
        })

        assert_equal 100, evaluator.evaluate_score
      end

      test "should handle JSON arrays" do
        json = '[{"name": "John"}, {"name": "Jane"}]'
        response = create_response(json)
        evaluator = FormatEvaluator.new(response, { format: :json })

        assert_equal 100, evaluator.evaluate_score
      end

      test "should handle markdown with multiple header levels" do
        markdown = "# H1\n## H2\n### H3\nContent"
        response = create_response(markdown)
        evaluator = FormatEvaluator.new(response, {
          format: :markdown,
          require_headers: true
        })

        assert_equal 100, evaluator.evaluate_score
      end
    end
  end
end

