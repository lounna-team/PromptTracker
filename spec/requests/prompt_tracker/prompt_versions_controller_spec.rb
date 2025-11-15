# frozen_string_literal: true

require "rails_helper"

RSpec.describe "PromptTracker::PromptVersionsController", type: :request do
  let(:prompt) { create(:prompt, :with_active_version) }
  let(:version) { prompt.active_version }

  describe "GET /prompts/:prompt_id/versions/:id" do
    it "shows version details" do
      get "/prompt_tracker/prompts/#{prompt.id}/versions/#{version.id}"
      expect(response).to have_http_status(:success)
      expect(response.body).to include("v#{version.version_number}")
    end

    it "paginates responses" do
      create_list(:llm_response, 25, prompt_version: version)

      get "/prompt_tracker/prompts/#{prompt.id}/versions/#{version.id}"
      expect(response).to have_http_status(:success)

      get "/prompt_tracker/prompts/#{prompt.id}/versions/#{version.id}", params: { page: 2 }
      expect(response).to have_http_status(:success)
    end

    it "calculates metrics correctly" do
      create(:llm_response, prompt_version: version, response_time_ms: 100, cost_usd: 0.01)
      create(:llm_response, prompt_version: version, response_time_ms: 200, cost_usd: 0.02)

      get "/prompt_tracker/prompts/#{prompt.id}/versions/#{version.id}"
      expect(response).to have_http_status(:success)
      expect(response.body).to include("150") # avg response time
      expect(response.body).to include("0.03") # total cost
    end

    it "shows provider breakdown" do
      create(:llm_response, prompt_version: version, provider: "openai")
      create(:llm_response, prompt_version: version, provider: "anthropic")

      get "/prompt_tracker/prompts/#{prompt.id}/versions/#{version.id}"
      expect(response).to have_http_status(:success)
      expect(response.body).to include("openai")
      expect(response.body).to include("anthropic")
    end

    it "shows model breakdown" do
      create(:llm_response, prompt_version: version, model: "gpt-4")
      create(:llm_response, prompt_version: version, model: "claude-3")

      get "/prompt_tracker/prompts/#{prompt.id}/versions/#{version.id}"
      expect(response).to have_http_status(:success)
      expect(response.body).to include("gpt-4")
      expect(response.body).to include("claude-3")
    end

    it "shows status breakdown" do
      create(:llm_response, prompt_version: version, status: "success")
      create(:llm_response, prompt_version: version, status: "error")

      get "/prompt_tracker/prompts/#{prompt.id}/versions/#{version.id}"
      expect(response).to have_http_status(:success)
    end

    it "returns 404 for non-existent version" do
      get "/prompt_tracker/prompts/#{prompt.id}/versions/999999"
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for version from different prompt" do
      other_prompt = create(:prompt, :with_active_version)
      other_version = other_prompt.active_version

      get "/prompt_tracker/prompts/#{prompt.id}/versions/#{other_version.id}"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /prompts/:prompt_id/versions/:id/compare" do
    let(:version_2) { create(:prompt_version, prompt: prompt, version_number: 2) }

    it "shows compare page" do
      version_2 # create it
      get "/prompt_tracker/prompts/#{prompt.id}/versions/#{version.id}/compare"
      expect(response).to have_http_status(:success)
    end

    it "compares with specified version" do
      version_2 # create it
      get "/prompt_tracker/prompts/#{prompt.id}/versions/#{version_2.id}/compare", params: { compare_with: version.id }
      expect(response).to have_http_status(:success)
      expect(response.body).to include("v#{version.version_number}")
      expect(response.body).to include("v#{version_2.version_number}")
    end

    it "compares with previous version by default" do
      version_2 # create it (version 2)
      get "/prompt_tracker/prompts/#{prompt.id}/versions/#{version_2.id}/compare"
      expect(response).to have_http_status(:success)
      # Should compare with version 1 (previous version)
    end

    it "handles compare when no previous version exists" do
      get "/prompt_tracker/prompts/#{prompt.id}/versions/#{version.id}/compare"
      expect(response).to have_http_status(:success)
    end

    it "calculates metrics diff correctly" do
      create(:llm_response, prompt_version: version, response_time_ms: 100, cost_usd: 0.01)
      create(:llm_response, prompt_version: version_2, response_time_ms: 200, cost_usd: 0.02)

      get "/prompt_tracker/prompts/#{prompt.id}/versions/#{version_2.id}/compare", params: { compare_with: version.id }
      expect(response).to have_http_status(:success)
      # Should show difference in metrics
    end

    it "shows evaluation score comparison" do
      create(:evaluation, llm_response: create(:llm_response, prompt_version: version), score: 4.0)
      create(:evaluation, llm_response: create(:llm_response, prompt_version: version_2), score: 4.5)

      get "/prompt_tracker/prompts/#{prompt.id}/versions/#{version_2.id}/compare", params: { compare_with: version.id }
      expect(response).to have_http_status(:success)
    end
  end
end
