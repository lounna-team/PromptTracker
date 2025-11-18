# frozen_string_literal: true

module PromptTracker
  # Controller for managing test suites.
  class PromptTestSuitesController < ApplicationController
    before_action :set_suite, only: [:show, :edit, :update, :destroy, :run]

    # GET /test-suites
    def index
      @suites = PromptTestSuite.order(created_at: :desc)
    end

    # GET /test-suites/:id
    def show
      @recent_runs = @suite.recent_runs(10)
      @tests = @suite.prompt_tests.order(created_at: :desc)
    end

    # GET /test-suites/new
    def new
      @suite = PromptTestSuite.new(tags: [])
    end

    # POST /test-suites
    def create
      @suite = PromptTestSuite.new(suite_params)

      if @suite.save
        redirect_to prompt_test_suite_path(@suite), notice: "Test suite created successfully."
      else
        render :new, status: :unprocessable_entity
      end
    end

    # GET /test-suites/:id/edit
    def edit
    end

    # PATCH/PUT /test-suites/:id
    def update
      if @suite.update(suite_params)
        redirect_to prompt_test_suite_path(@suite), notice: "Test suite updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /test-suites/:id
    def destroy
      @suite.destroy
      redirect_to prompt_test_suites_path, notice: "Test suite deleted successfully."
    end

    # POST /test-suites/:id/run
    def run
      # Run suite in background (we'll create the job later)
      # For now, show a message
      redirect_to prompt_test_suite_path(@suite),
                  alert: "Suite execution requires LLM API integration. Please use the API or background job."
    end

    private

    def set_suite
      @suite = PromptTestSuite.find(params[:id])
    end

    def suite_params
      params.require(:prompt_test_suite).permit(
        :name,
        :description,
        :prompt_id,
        :enabled,
        tags: [],
        metadata: {}
      )
    end
  end
end

