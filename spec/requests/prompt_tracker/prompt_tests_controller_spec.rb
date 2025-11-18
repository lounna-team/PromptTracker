# frozen_string_literal: true

require "rails_helper"

RSpec.describe "PromptTracker::PromptTestsController", type: :request do
  let(:prompt) { create(:prompt) }
  let(:version) { create(:prompt_version, prompt: prompt, status: "active") }
  let(:test) { create(:prompt_test, prompt_version: version) }

  describe "GET /prompts/:prompt_id/versions/:version_id/tests" do
    it "returns success" do
      get "/prompt_tracker/prompts/#{prompt.id}/versions/#{version.id}/tests"
      expect(response).to have_http_status(:success)
    end

    it "lists all tests for the version" do
      test1 = create(:prompt_test, prompt_version: version, name: "Test 1")
      test2 = create(:prompt_test, prompt_version: version, name: "Test 2")

      get "/prompt_tracker/prompts/#{prompt.id}/versions/#{version.id}/tests"

      expect(response.body).to include("Test 1")
      expect(response.body).to include("Test 2")
    end
  end

  describe "GET /prompts/:prompt_id/versions/:version_id/tests/:id" do
    it "shows test details" do
      get "/prompt_tracker/prompts/#{prompt.id}/versions/#{version.id}/tests/#{test.id}"
      expect(response).to have_http_status(:success)
      expect(response.body).to include(test.name)
    end
  end

  describe "POST /prompts/:prompt_id/versions/:version_id/tests/:id/run" do
    it "runs a single test" do
      post "/prompt_tracker/prompts/#{prompt.id}/versions/#{version.id}/tests/#{test.id}/run"

      expect(response).to redirect_to("/prompt_tracker/prompts/#{prompt.id}/versions/#{version.id}/tests/#{test.id}")
      follow_redirect!
      expect(response.body).to match(/Test (passed|failed)/)
    end
  end

  describe "POST /prompts/:prompt_id/versions/:version_id/tests/run_all" do
    it "runs all enabled tests" do
      test1 = create(:prompt_test, prompt_version: version, enabled: true, name: "Test 1")
      test2 = create(:prompt_test, prompt_version: version, enabled: true, name: "Test 2")
      test3 = create(:prompt_test, prompt_version: version, enabled: false, name: "Test 3")

      expect {
        post "/prompt_tracker/prompts/#{prompt.id}/versions/#{version.id}/tests/run_all"
      }.to change(PromptTracker::PromptTestRun, :count).by(2) # Only enabled tests

      expect(response).to redirect_to("/prompt_tracker/prompts/#{prompt.id}/versions/#{version.id}/tests")
      follow_redirect!
      expect(response.body).to match(/Completed 2 tests/)
    end

    it "shows success or failure message based on test results" do
      create(:prompt_test, prompt_version: version, enabled: true)
      create(:prompt_test, prompt_version: version, enabled: true)

      post "/prompt_tracker/prompts/#{prompt.id}/versions/#{version.id}/tests/run_all"

      expect(response).to redirect_to("/prompt_tracker/prompts/#{prompt.id}/versions/#{version.id}/tests")
      follow_redirect!
      # Tests may pass or fail depending on mock response matching expected patterns
      expect(response.body).to match(/Completed 2 tests|All 2 tests passed/)
    end

    it "shows alert when no enabled tests exist" do
      create(:prompt_test, prompt_version: version, enabled: false)

      post "/prompt_tracker/prompts/#{prompt.id}/versions/#{version.id}/tests/run_all"

      expect(response).to redirect_to("/prompt_tracker/prompts/#{prompt.id}/versions/#{version.id}/tests")
      follow_redirect!
      expect(response.body).to include("No enabled tests to run")
    end

    it "handles test failures gracefully" do
      # Create a test that will fail (no expected patterns will match mock response)
      create(:prompt_test,
        prompt_version: version,
        enabled: true,
        expected_patterns: ["IMPOSSIBLE_PATTERN_THAT_WONT_MATCH"]
      )

      post "/prompt_tracker/prompts/#{prompt.id}/versions/#{version.id}/tests/run_all"

      expect(response).to redirect_to("/prompt_tracker/prompts/#{prompt.id}/versions/#{version.id}/tests")
      follow_redirect!
      expect(response.body).to match(/Completed 1 tests/)
    end
  end
end
