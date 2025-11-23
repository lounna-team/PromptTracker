# frozen_string_literal: true

module PromptTracker
  module Monitoring
    # Dashboard for the Monitoring section - production tracking
    #
    # Shows overview of:
    # - Recent production LLM calls
    # - Auto-evaluation results
    # - Quality metrics
    # - Alerts for failing evaluations
    #
    class DashboardController < ApplicationController
      def index
        # Only show production calls (not test runs)
        @recent_responses = LlmResponse.production_calls
                                       .includes(:prompt_version, :prompt, evaluations: [])
                                       .order(created_at: :desc)

        # Apply filters
        if params[:prompt_id].present?
          @recent_responses = @recent_responses.joins(prompt_version: :prompt)
                                               .where(prompt_tracker_prompts: { id: params[:prompt_id] })
        end

        if params[:environment].present?
          @recent_responses = @recent_responses.where(environment: params[:environment])
        end

        if params[:status].present?
          @recent_responses = @recent_responses.where(status: params[:status])
        end

        if params[:evaluator_type].present?
          @recent_responses = @recent_responses.joins(:evaluations)
                                               .where(prompt_tracker_evaluations: { evaluator_type: params[:evaluator_type] })
                                               .distinct
        end

        # Limit results
        @recent_responses = @recent_responses.limit(50)

        # Get filter options
        @prompts = Prompt.active.order(:name)
        @environments = LlmResponse.production_calls.distinct.pluck(:environment).compact.sort
        @statuses = LlmResponse::STATUSES
        @evaluator_types = Evaluation::EVALUATOR_TYPES

        # Statistics (last 24 hours)
        since_yesterday = Time.current - 24.hours
        @calls_today = LlmResponse.production_calls
                                  .where("created_at >= ?", since_yesterday)
                                  .count

        @evaluations_today = Evaluation.tracked
                                       .where("created_at >= ?", since_yesterday)
                                       .count

        # Quality metrics
        recent_evals = Evaluation.tracked
                                 .where("created_at >= ?", since_yesterday)

        @avg_score = if recent_evals.any?
          recent_evals.average(:score).to_f.round(2)
        else
          0
        end

        # Alerts: evaluations below threshold
        @failing_evaluations = Evaluation.tracked
                                         .joins(:llm_response)
                                         .where("prompt_tracker_evaluations.created_at >= ?", since_yesterday)
                                         .where("prompt_tracker_evaluations.score < 0.7") # TODO: make threshold configurable
                                         .order(created_at: :desc)
                                         .limit(10)
      end
    end
  end
end
