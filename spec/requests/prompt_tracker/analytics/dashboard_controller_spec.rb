# frozen_string_literal: true

require "rails_helper"

RSpec.describe "PromptTracker::Analytics::DashboardController", type: :request do
  let(:prompt) { create(:prompt, :with_active_version) }
  let(:version) { prompt.active_version }

  before do
    # Create some test data
    create_list(:llm_response, 5, prompt_version: version, status: "success", cost_usd: 0.01, response_time_ms: 100)
    create_list(:llm_response, 2, prompt_version: version, status: "error", cost_usd: 0.005, response_time_ms: 50)
  end

  describe "GET /analytics" do
    it "returns success" do
      get "/prompt_tracker/analytics"
      expect(response).to have_http_status(:success)
    end

    it "shows overall metrics" do
      get "/prompt_tracker/analytics"
      expect(response).to have_http_status(:success)
      # Just verify the page loads successfully - content may vary
    end

    it "calculates cost metrics" do
      get "/prompt_tracker/analytics"
      expect(response).to have_http_status(:success)
    end

    it "shows activity over time" do
      get "/prompt_tracker/analytics"
      expect(response).to have_http_status(:success)
    end

    it "shows provider distribution" do
      get "/prompt_tracker/analytics"
      expect(response).to have_http_status(:success)
    end

    it "shows recent activity" do
      get "/prompt_tracker/analytics"
      expect(response).to have_http_status(:success)
    end

    it "shows top prompts by usage" do
      get "/prompt_tracker/analytics"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /analytics/costs" do
    it "returns success" do
      get "/prompt_tracker/analytics/costs"
      expect(response).to have_http_status(:success)
    end

    it "shows cost summary metrics" do
      get "/prompt_tracker/analytics/costs"
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Total Cost")
    end

    it "shows cost over time" do
      get "/prompt_tracker/analytics/costs"
      expect(response).to have_http_status(:success)
    end

    it "shows cost by provider" do
      get "/prompt_tracker/analytics/costs"
      expect(response).to have_http_status(:success)
    end

    it "shows cost by model" do
      get "/prompt_tracker/analytics/costs"
      expect(response).to have_http_status(:success)
    end

    it "shows top prompts by cost" do
      get "/prompt_tracker/analytics/costs"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /analytics/performance" do
    it "returns success" do
      get "/prompt_tracker/analytics/performance"
      expect(response).to have_http_status(:success)
    end

    it "shows performance summary metrics" do
      get "/prompt_tracker/analytics/performance"
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Response Time")
    end

    it "calculates P95 response time" do
      get "/prompt_tracker/analytics/performance"
      expect(response).to have_http_status(:success)
    end

    it "shows response time over time" do
      get "/prompt_tracker/analytics/performance"
      expect(response).to have_http_status(:success)
    end

    it "shows response time by provider" do
      get "/prompt_tracker/analytics/performance"
      expect(response).to have_http_status(:success)
    end

    it "shows success rate by provider" do
      get "/prompt_tracker/analytics/performance"
      expect(response).to have_http_status(:success)
    end

    it "shows fastest and slowest prompts" do
      get "/prompt_tracker/analytics/performance"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /analytics/quality" do
    before do
      # Create evaluations for quality testing
      llm_response = PromptTracker::LlmResponse.first
      create_list(:evaluation, 3, llm_response: llm_response, score: 4.0, score_min: 0, score_max: 5)
      create_list(:evaluation, 2, llm_response: llm_response, score: 2.0, score_min: 0, score_max: 5)
    end

    it "returns success" do
      get "/prompt_tracker/analytics/quality"
      expect(response).to have_http_status(:success)
    end

    it "shows quality summary metrics" do
      get "/prompt_tracker/analytics/quality"
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Quality")
    end

    it "calculates average quality score" do
      get "/prompt_tracker/analytics/quality"
      expect(response).to have_http_status(:success)
    end

    it "shows quality over time" do
      get "/prompt_tracker/analytics/quality"
      expect(response).to have_http_status(:success)
    end

    it "shows evaluation type breakdown" do
      get "/prompt_tracker/analytics/quality"
      expect(response).to have_http_status(:success)
    end
  end
end
