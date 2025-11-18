# frozen_string_literal: true

module PromptTracker
  # Controller for viewing test suite run results.
  class PromptTestSuiteRunsController < ApplicationController
    before_action :set_suite_run, only: [:show]

    # GET /suite-runs
    def index
      @suite_runs = PromptTestSuiteRun.includes(:prompt_test_suite)
                                       .order(created_at: :desc)
                                       .page(params[:page])
                                       .per(50)

      # Filter by status if provided
      if params[:status].present?
        @suite_runs = @suite_runs.where(status: params[:status])
      end
    end

    # GET /suite-runs/:id
    def show
      @suite = @suite_run.prompt_test_suite
      @test_runs = @suite_run.prompt_test_runs.includes(:prompt_test).order(created_at: :desc)
    end

    private

    def set_suite_run
      @suite_run = PromptTestSuiteRun.find(params[:id])
    end
  end
end

