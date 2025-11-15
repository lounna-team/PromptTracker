# frozen_string_literal: true

module PromptTracker
  # Background job for running evaluators asynchronously.
  #
  # This job is used for expensive evaluators (like LLM judges) that
  # should not block the request cycle. It:
  # - Checks dependencies before running (if configured)
  # - Builds and executes the evaluator
  # - Creates the evaluation record
  # - Handles errors gracefully with retries
  #
  # @example Schedule an evaluation job
  #   EvaluationJob.perform_later(response_id, config_id)
  #
  # @example Schedule with dependency check
  #   EvaluationJob.perform_later(response_id, config_id, check_dependency: true)
  #
  class EvaluationJob < ApplicationJob
    queue_as :default

    # Retry on standard errors with exponential backoff
    retry_on StandardError, wait: :exponentially_longer, attempts: 3

    # Performs the evaluation
    #
    # @param llm_response_id [Integer] ID of the response to evaluate
    # @param evaluator_config_id [Integer] ID of the evaluator config
    # @param check_dependency [Boolean] whether to check dependencies
    # @return [void]
    def perform(llm_response_id, evaluator_config_id, check_dependency: false)
      llm_response = LlmResponse.find(llm_response_id)
      config = EvaluatorConfig.find(evaluator_config_id)

      # Check dependency if required
      if check_dependency && !config.dependency_met?(llm_response)
        Rails.logger.info(
          "Skipping #{config.evaluator_key} - dependency not met " \
          "(requires #{config.depends_on} >= #{config.min_dependency_score || 80})"
        )
        return
      end

      # Build and run the evaluator
      evaluator = config.build_evaluator(llm_response)

      # Run the evaluator (returns an Evaluation record)
      evaluation = evaluator.evaluate

      # Update metadata with job info
      evaluation.update!(
        metadata: (evaluation.metadata || {}).merge(
          job_id: job_id,
          weight: config.weight,
          priority: config.priority,
          dependency: config.depends_on,
          evaluator_config_id: config.id,
          executed_at: Time.current
        )
      )

      Rails.logger.info("Completed evaluation: #{config.evaluator_key} for response #{llm_response_id}")
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error("Evaluation job failed - record not found: #{e.message}")
      # Don't retry if record doesn't exist
    rescue StandardError => e
      Rails.logger.error("Evaluation job failed for #{config&.evaluator_key}: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      raise # Let retry logic handle it
    end
  end
end
