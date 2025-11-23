# frozen_string_literal: true

module PromptTracker
  module Tests
    # Controller for viewing test runs in the Tests section
    #
    # Shows only test runs (LlmResponses with is_test_run: true)
    # and their evaluations (evaluation_context: 'test_run')
    #
    class PromptTestRunsController < PromptTracker::PromptTestRunsController
      # Inherits all actions from parent controller
      # This provides a cleaner URL structure under /tests/runs
    end
  end
end

