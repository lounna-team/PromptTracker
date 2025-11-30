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
    it "starts a single test in the background" do
      expect {
        post "/prompt_tracker/prompts/#{prompt.id}/versions/#{version.id}/tests/#{test.id}/run"
      }.to change(PromptTracker::PromptTestRun, :count).by(1)

      expect(response).to redirect_to("/prompt_tracker/prompts/#{prompt.id}/versions/#{version.id}/tests/#{test.id}")
      follow_redirect!
      expect(response.body).to match(/Test started in the background/)

      # Verify test run was created with "running" status
      test_run = PromptTracker::PromptTestRun.last
      expect(test_run.status).to eq("running")
      expect(test_run.prompt_test).to eq(test)
    end
  end

  describe "POST /prompts/:prompt_id/versions/:version_id/tests/run_all" do
    it "starts all enabled tests in the background" do
      test1 = create(:prompt_test, prompt_version: version, enabled: true, name: "Test 1")
      test2 = create(:prompt_test, prompt_version: version, enabled: true, name: "Test 2")
      test3 = create(:prompt_test, prompt_version: version, enabled: false, name: "Test 3")

      expect {
        post "/prompt_tracker/prompts/#{prompt.id}/versions/#{version.id}/tests/run_all"
      }.to change(PromptTracker::PromptTestRun, :count).by(2) # Only enabled tests

      expect(response).to redirect_to("/prompt_tracker/prompts/#{prompt.id}/versions/#{version.id}/tests")
      follow_redirect!
      expect(response.body).to match(/Started 2 tests in the background/)

      # Verify test runs were created with "running" status
      test_runs = PromptTracker::PromptTestRun.last(2)
      expect(test_runs.map(&:status)).to all(eq("running"))
    end

    it "enqueues background jobs for each enabled test" do
      create(:prompt_test, prompt_version: version, enabled: true)
      create(:prompt_test, prompt_version: version, enabled: true)

      post "/prompt_tracker/prompts/#{prompt.id}/versions/#{version.id}/tests/run_all"

      expect(response).to redirect_to("/prompt_tracker/prompts/#{prompt.id}/versions/#{version.id}/tests")
      follow_redirect!
      expect(response.body).to match(/Started 2 tests in the background/)
    end

    it "shows alert when no enabled tests exist" do
      create(:prompt_test, prompt_version: version, enabled: false)

      post "/prompt_tracker/prompts/#{prompt.id}/versions/#{version.id}/tests/run_all"

      expect(response).to redirect_to("/prompt_tracker/prompts/#{prompt.id}/versions/#{version.id}/tests")
      follow_redirect!
      expect(response.body).to include("No enabled tests to run")
    end

    it "creates test runs for all enabled tests" do
      test1 = create(:prompt_test, prompt_version: version, enabled: true)
      test2 = create(:prompt_test, prompt_version: version, enabled: true)

      expect {
        post "/prompt_tracker/prompts/#{prompt.id}/versions/#{version.id}/tests/run_all"
      }.to change(PromptTracker::PromptTestRun, :count).by(2)

      # Verify metadata is set correctly
      test_runs = PromptTracker::PromptTestRun.last(2)
      expect(test_runs.map { |tr| tr.metadata["triggered_by"] }).to all(eq("run_all"))
    end
  end
end
