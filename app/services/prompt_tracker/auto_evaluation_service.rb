# frozen_string_literal: true

module PromptTracker
  # Service for automatically evaluating LLM responses.
  #
  # This service runs when a new LLM response is created and executes
  # all enabled evaluators configured for the prompt. It handles:
  # - Running independent evaluators first
  # - Running dependent evaluators only if dependencies are met
  # - Executing sync evaluators immediately
  # - Scheduling async evaluators as background jobs
  #
  # @example Manually trigger auto-evaluation
  #   AutoEvaluationService.evaluate(llm_response)
  #
  # @example Auto-evaluation is triggered automatically
  #   # When a response is created, after_create callback triggers evaluation
  #   response = LlmResponse.create!(...)
  #   # AutoEvaluationService.evaluate(response) is called automatically
  #
  class AutoEvaluationService
    # Evaluates a response using all configured evaluators
    #
    # @param llm_response [LlmResponse] the response to evaluate
    # @return [void]
    def self.evaluate(llm_response)
      new(llm_response).evaluate
    end

    # Initialize the service
    #
    # @param llm_response [LlmResponse] the response to evaluate
    def initialize(llm_response)
      @llm_response = llm_response
      @prompt = llm_response.prompt
    end

    # Runs all configured evaluators for this response
    #
    # @return [void]
    def evaluate
      return unless @prompt

      # Phase 1: Run independent evaluators (no dependencies)
      independent_configs = @prompt.evaluator_configs.enabled.independent.by_priority
      independent_configs.each { |config| run_evaluation(config) }

      # Phase 2: Run dependent evaluators (only if dependencies are met)
      dependent_configs = @prompt.evaluator_configs.enabled.dependent.by_priority
      dependent_configs.each do |config|
        next unless config.dependency_met?(@llm_response)

        run_evaluation(config)
      end
    end

    private

    # Runs a single evaluator (sync or async)
    #
    # @param config [EvaluatorConfig] the evaluator configuration
    # @return [void]
    def run_evaluation(config)
      if config.sync?
        run_sync_evaluation(config)
      else
        run_async_evaluation(config)
      end
    end

    # Runs a synchronous evaluation immediately
    #
    # @param config [EvaluatorConfig] the evaluator configuration
    # @return [void]
    def run_sync_evaluation(config)
      evaluator = config.build_evaluator(@llm_response)
      result = evaluator.evaluate

      create_evaluation(config, result)
    end

    # Schedules an asynchronous evaluation as a background job
    #
    # @param config [EvaluatorConfig] the evaluator configuration
    # @return [void]
    def run_async_evaluation(config)
      EvaluationJob.perform_later(
        @llm_response.id,
        config.id,
        check_dependency: config.has_dependency?
      )
    end

    # Creates an evaluation record from evaluator result
    #
    # @param config [EvaluatorConfig] the evaluator configuration
    # @param evaluation [Evaluation] the evaluation record created by the evaluator
    # @return [void]
    def create_evaluation(config, evaluation)
      # The evaluator already created the evaluation via EvaluationService
      # Just update metadata with weight and priority
      evaluation.update!(
        metadata: (evaluation.metadata || {}).merge(
          weight: config.weight,
          priority: config.priority,
          dependency: config.depends_on,
          evaluator_config_id: config.id
        )
      )
    end
  end
end
