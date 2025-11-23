# frozen_string_literal: true

module PromptTracker
  module Tests
    # Dashboard for the Tests section - pre-deployment validation
    #
    # Shows overview of:
    # - Recent test runs
    # - Pass/fail rates
    # - Test coverage by prompt
    #
    class DashboardController < ApplicationController
      def index
        @recent_test_runs = PromptTestRun.order(created_at: :desc).limit(10)

        # Test statistics
        @total_tests = PromptTest.count
        @total_runs_today = PromptTestRun.where("created_at >= ?", Time.current.beginning_of_day).count

        # Pass/fail rates (last 100 runs)
        recent_runs = PromptTestRun.order(created_at: :desc).limit(100)
        @pass_rate = if recent_runs.any?
          (recent_runs.where(status: "passed").count.to_f / recent_runs.count * 100).round(1)
        else
          0
        end
      end
    end
  end
end
