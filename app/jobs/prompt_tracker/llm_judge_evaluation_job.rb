# frozen_string_literal: true

module PromptTracker
  # Background job for running LLM judge evaluations without requiring an EvaluatorConfig.
  #
  # This job is used for ad-hoc LLM judge evaluations triggered from the manual
  # evaluation form. Unlike EvaluationJob, it doesn't require a saved EvaluatorConfig,
  # making it suitable for one-off evaluations with custom configurations.
  #
  # @example Schedule an LLM judge evaluation
  #   LlmJudgeEvaluationJob.perform_later(response_id, config)
  #
  class LlmJudgeEvaluationJob < ApplicationJob
    queue_as :default

    # Retry on standard errors with exponential backoff
    retry_on StandardError, wait: :exponentially_longer, attempts: 3

    # Performs the LLM judge evaluation
    #
    # @param llm_response_id [Integer] ID of the response to evaluate
    # @param config [Hash] Configuration for the LLM judge
    # @option config [String] :judge_model The LLM model to use as judge
    # @option config [Array<String>] :criteria Criteria to evaluate
    # @option config [String] :custom_instructions Additional instructions
    # @option config [Integer] :score_min Minimum score (default: 0)
    # @option config [Integer] :score_max Maximum score (default: 100)
    # @return [void]
    def perform(llm_response_id, config)
      llm_response = LlmResponse.find(llm_response_id)
      evaluator_key = :gpt4_judge

      # Build the evaluator with the provided config
      evaluator = EvaluatorRegistry.build(evaluator_key, llm_response, config)

      # Run the evaluator with a block that calls the LLM API
      # NOTE: This is a mock implementation. In production, you would:
      # 1. Call the actual LLM API (OpenAI, Anthropic, etc.)
      # 2. Pass the API response to the evaluator
      evaluation = evaluator.evaluate do |judge_prompt|
        # TODO: Replace this with actual LLM API call
        # Example for OpenAI:
        # client = OpenAI::Client.new
        # response = client.chat(
        #   parameters: {
        #     model: config[:judge_model] || "gpt-4",
        #     messages: [{ role: "user", content: judge_prompt }]
        #   }
        # )
        # response.dig("choices", 0, "message", "content")

        # Mock response for now
        generate_mock_judge_response(config, llm_response)
      end

      # Update metadata with job info
      evaluation.update!(
        metadata: (evaluation.metadata || {}).merge(
          job_id: job_id,
          executed_at: Time.current,
          manual_evaluation: true,
          config: config
        )
      )

      Rails.logger.info(
        "LLM Judge evaluation completed for response #{llm_response_id}: " \
        "Score #{evaluation.score}/#{config[:score_max]}"
      )
    rescue StandardError => e
      Rails.logger.error(
        "LLM Judge evaluation failed for response #{llm_response_id}: #{e.message}"
      )
      raise
    end

    private

    # Generates a mock LLM judge response for testing
    # TODO: Remove this when actual LLM API integration is implemented
    #
    # @param config [Hash] The judge configuration
    # @param llm_response [LlmResponse] The response being evaluated
    # @return [String] Mock judge response in expected format
    def generate_mock_judge_response(config, llm_response)
      score_max = config[:score_max] || 100
      criteria = config[:criteria] || []

      # Generate random but reasonable scores
      overall_score = rand(score_max * 0.6..score_max * 0.95).round(1)

      criteria_scores = criteria.map do |criterion|
        score = rand(score_max * 0.5..score_max).round(1)
        "#{criterion}: #{score}"
      end.join("\n")

      <<~RESPONSE
        OVERALL SCORE: #{overall_score}

        CRITERIA SCORES:
        #{criteria_scores}

        FEEDBACK:
        [MOCK EVALUATION] This is a simulated LLM judge evaluation.
        The response appears to be well-structured and addresses the prompt appropriately.
        To enable real LLM judge evaluations, configure your LLM API credentials and
        update the LlmJudgeEvaluationJob to call the actual API.

        Response length: #{llm_response.response_text.length} characters
        Model used: #{llm_response.model}
      RESPONSE
    end
  end
end
