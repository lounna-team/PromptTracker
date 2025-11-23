# frozen_string_literal: true

module PromptTracker
  module Monitoring
    # Controller for viewing production evaluations (tracked calls only)
    #
    # Shows auto-evaluation results from production LLM calls.
    # Allows creating manual evaluations with context set to "manual".
    #
    class EvaluationsController < ApplicationController
      def index
        @evaluations = Evaluation.tracked
                                 .includes(llm_response: [ :prompt_version, :prompt ])
                                 .order(created_at: :desc)

        # Filter by prompt
        if params[:prompt_id].present?
          @evaluations = @evaluations.joins(llm_response: :prompt)
                                     .where(prompt_tracker_prompts: { id: params[:prompt_id] })
        end

        # Filter by prompt version
        if params[:prompt_version_id].present?
          @evaluations = @evaluations.joins(:llm_response)
                                     .where(prompt_tracker_llm_responses: { prompt_version_id: params[:prompt_version_id] })
        end

        # Filter by score range
        if params[:min_score].present?
          @evaluations = @evaluations.where("score >= ?", params[:min_score])
        end

        if params[:max_score].present?
          @evaluations = @evaluations.where("score <= ?", params[:max_score])
        end

        # Filter by evaluator type
        if params[:evaluator_type].present?
          @evaluations = @evaluations.where(evaluator_type: params[:evaluator_type])
        end

        @evaluations = @evaluations.page(params[:page]).per(25)

        # Load prompts and versions for filter dropdowns
        @prompts = Prompt.active.order(:name)
        if params[:prompt_id].present?
          @prompt_versions = PromptVersion.where(prompt_id: params[:prompt_id]).order(version_number: :desc)
        else
          @prompt_versions = []
        end
      end

      def show
        @evaluation = Evaluation.tracked.find(params[:id])
        @response = @evaluation.llm_response
      end

      def create
        @response = LlmResponse.production_calls.find(params[:evaluation][:llm_response_id])

        # Determine evaluation type and route accordingly
        if params[:llm_judge].present?
          create_llm_judge_evaluation
        else
          # This is a manual human evaluation
          create_manual_evaluation
        end
      rescue ActiveRecord::RecordNotFound
        redirect_to monitoring_responses_path, alert: "Response not found"
      end

      def form_template
        # Return partial for dynamic form loading
        evaluator_key = params[:evaluator_key]
        render partial: "evaluations/forms/#{evaluator_key}", locals: { response: nil }
      end

      private

      # Creates a manual evaluation (human with manual scores)
      def create_manual_evaluation
        evaluation = EvaluationService.create_human(
          llm_response: @response,
          score: params[:evaluation][:score].to_f,
          evaluator_id: params[:evaluation][:evaluator_id],
          score_min: params[:evaluation][:score_min]&.to_f || 0,
          score_max: params[:evaluation][:score_max]&.to_f || 5,
          criteria_scores: params[:evaluation][:criteria_scores] || {},
          feedback: params[:evaluation][:feedback],
          metadata: params[:evaluation][:metadata] || {},
          evaluation_context: "manual"
        )

        if evaluation.persisted?
          redirect_to monitoring_response_path(@response), notice: "Manual evaluation created successfully!"
        else
          redirect_to monitoring_response_path(@response), alert: "Error creating evaluation: #{evaluation.errors.full_messages.join(', ')}"
        end
      end

      # Creates an LLM judge evaluation
      def create_llm_judge_evaluation
        judge_params = params[:llm_judge]

        # Build configuration for the LLM judge
        config = {
          judge_model: judge_params[:judge_model],
          criteria: judge_params[:criteria] || [],
          custom_instructions: judge_params[:custom_instructions],
          score_min: judge_params[:score_min]&.to_i || 0,
          score_max: judge_params[:score_max]&.to_i || 100
        }

        # Build and run the evaluator
        evaluator = Evaluators::LlmJudgeEvaluator.new(@response, config)
        evaluation = evaluator.evaluate

        # Update context to manual since this was triggered manually
        evaluation.update!(evaluation_context: "manual")

        redirect_to monitoring_response_path(@response),
                    notice: "LLM Judge evaluation completed! Score: #{evaluation.score}"
      rescue => e
        redirect_to monitoring_response_path(@response),
                    alert: "Error running LLM judge: #{e.message}"
      end
    end
  end
end
