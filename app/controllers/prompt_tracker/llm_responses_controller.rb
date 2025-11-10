# frozen_string_literal: true

module PromptTracker
  # Controller for viewing LLM responses
  class LlmResponsesController < ApplicationController
    # GET /responses
    # List all LLM responses with filtering
    def index
      @responses = LlmResponse.includes(:prompt_version, :evaluations).order(created_at: :desc)

      # Filter by provider
      @responses = @responses.where(provider: params[:provider]) if params[:provider].present?

      # Filter by model
      @responses = @responses.where(model: params[:model]) if params[:model].present?

      # Filter by status
      @responses = @responses.where(status: params[:status]) if params[:status].present?

      # Search in rendered_prompt or response_text
      if params[:q].present?
        query = "%#{params[:q]}%"
        @responses = @responses.where("rendered_prompt LIKE ? OR response_text LIKE ?", query, query)
      end

      # Date range filter
      if params[:start_date].present?
        @responses = @responses.where("created_at >= ?", params[:start_date])
      end
      if params[:end_date].present?
        @responses = @responses.where("created_at <= ?", params[:end_date])
      end

      # Pagination
      @responses = @responses.page(params[:page]).per(20)

      # Get filter options
      @providers = LlmResponse.distinct.pluck(:provider).compact.sort
      @models = LlmResponse.distinct.pluck(:model).compact.sort
      @statuses = LlmResponse.distinct.pluck(:status).compact.sort
    end

    # GET /responses/:id
    # Show response details with evaluations
    def show
      @response = LlmResponse.includes(:prompt_version, :evaluations).find(params[:id])
      @prompt = @response.prompt_version.prompt
      @version = @response.prompt_version
      @evaluations = @response.evaluations.order(created_at: :desc)

      # Calculate average score
      @avg_score = @evaluations.any? ? PromptTracker::EvaluationHelpers.average_score_for_response(@response) : nil
    end
  end
end
