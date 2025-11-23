# frozen_string_literal: true

module PromptTracker
  module Monitoring
    # Controller for viewing production LLM responses (tracked calls only)
    #
    # Filters out test runs and shows only real production/staging calls
    # from the host application.
    #
    class LlmResponsesController < ApplicationController
      def index
        @responses = LlmResponse.production_calls
                                .includes(:prompt_version, :evaluations)
                                .order(created_at: :desc)

        # Filter by environment if specified
        if params[:environment].present?
          @responses = @responses.where(environment: params[:environment])
        end

        # Filter by prompt if specified
        if params[:prompt_id].present?
          @responses = @responses.joins(prompt_version: :prompt)
                                 .where(prompt_tracker_prompts: { id: params[:prompt_id] })
        end

        # Filter by date range
        if params[:start_date].present?
          @responses = @responses.where("created_at >= ?", params[:start_date])
        end

        if params[:end_date].present?
          @responses = @responses.where("created_at <= ?", params[:end_date])
        end

        @responses = @responses.page(params[:page]).per(25)
      end

      def show
        @response = LlmResponse.production_calls.find(params[:id])
        @evaluations = @response.evaluations.tracked.order(created_at: :desc)
        @prompt = @response.prompt_version.prompt
        @version = @response.prompt_version
      end

      def search
        query = params[:q]

        @responses = LlmResponse.production_calls

        if query.present?
          @responses = @responses.where(
            "response_text ILIKE ? OR rendered_prompt ILIKE ?",
            "%#{query}%",
            "%#{query}%"
          )
        end

        @responses = @responses.order(created_at: :desc)
                               .page(params[:page])
                               .per(25)

        render :index
      end
    end
  end
end
