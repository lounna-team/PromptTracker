# frozen_string_literal: true

module PromptTracker
  # Controller for viewing prompt versions
  class PromptVersionsController < ApplicationController
    before_action :set_prompt
    before_action :set_version, only: [:show, :compare, :activate]

    # GET /prompts/:prompt_id/versions/:id
    # Show version details with tests
    def show
      @tests = @version.prompt_tests.includes(:prompt_test_runs).order(created_at: :desc)

      # Calculate metrics
      @total_calls = @version.llm_responses.count
      @avg_response_time = @version.average_response_time_ms
      @total_cost = @version.total_cost_usd
      @avg_score = @version.evaluations.any? ? PromptTracker::EvaluationHelpers.average_score_for_version(@version) : nil

      # Provider breakdown
      @responses_by_provider = @version.llm_responses.group(:provider).count
      @responses_by_model = @version.llm_responses.group(:model).count
      @responses_by_status = @version.llm_responses.group(:status).count
    end

    # GET /prompts/:prompt_id/versions/:id/compare
    # Compare this version with another
    def compare
      # Get comparison version (from params or default to previous version)
      if params[:compare_with].present?
        @compare_version = @prompt.prompt_versions.find(params[:compare_with])
      else
        # Default to previous version
        @compare_version = @prompt.prompt_versions
                                  .where("version_number < ?", @version.version_number)
                                  .order(version_number: :desc)
                                  .first
      end

      if @compare_version
        # Calculate metrics for both versions
        @version_metrics = calculate_version_metrics(@version)
        @compare_metrics = calculate_version_metrics(@compare_version)

        # Calculate differences
        @metrics_diff = {
          calls: @version_metrics[:calls] - @compare_metrics[:calls],
          avg_response_time: @version_metrics[:avg_response_time].to_f - @compare_metrics[:avg_response_time].to_f,
          total_cost: @version_metrics[:total_cost].to_f - @compare_metrics[:total_cost].to_f,
          avg_score: (@version_metrics[:avg_score].to_f - @compare_metrics[:avg_score].to_f).round(2)
        }
      end

      # Get all versions for comparison dropdown
      @all_versions = @prompt.prompt_versions.order(version_number: :desc)
    end

    # POST /prompts/:prompt_id/versions/:id/activate
    # Activate this version and deprecate all others
    def activate
      unless @version.draft? || @version.deprecated?
        redirect_to prompt_prompt_version_path(@prompt, @version), alert: "Version is already active."
        return
      end

      @version.activate!
      redirect_to prompt_prompt_version_path(@prompt, @version), notice: "Version activated successfully."
    end

    private

    def set_prompt
      @prompt = Prompt.find(params[:prompt_id])
    end

    def set_version
      @version = @prompt.prompt_versions.includes(:llm_responses).find(params[:id])
    end

    def calculate_version_metrics(version)
      {
        calls: version.llm_responses.count,
        avg_response_time: version.average_response_time_ms || 0,
        total_cost: version.total_cost_usd || 0,
        avg_score: version.evaluations.any? ? PromptTracker::EvaluationHelpers.average_score_for_version(version) : 0
      }
    end
  end
end
