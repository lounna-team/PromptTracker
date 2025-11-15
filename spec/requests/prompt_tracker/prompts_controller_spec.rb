# frozen_string_literal: true

require "rails_helper"

RSpec.describe "PromptTracker::PromptsController", type: :request do
  let(:prompt) { create(:prompt, :with_active_version) }

  describe "GET /prompts" do
    it "returns success" do
      get "/prompt_tracker/prompts"
      expect(response).to have_http_status(:success)
    end

    it "searches prompts by name" do
      prompt # create the prompt
      get "/prompt_tracker/prompts", params: { q: prompt.name }
      expect(response).to have_http_status(:success)
      expect(response.body).to include(prompt.name)
    end

    it "searches prompts by description" do
      prompt # create the prompt
      get "/prompt_tracker/prompts", params: { q: prompt.description }
      expect(response).to have_http_status(:success)
      expect(response.body).to include(prompt.description)
    end

    it "filters prompts by category" do
      prompt # create the prompt
      get "/prompt_tracker/prompts", params: { category: prompt.category }
      expect(response).to have_http_status(:success)
      expect(response.body).to include(prompt.name)
    end

    it "filters prompts by tag" do
      tagged_prompt = create(:prompt, tags: ["test-tag"])
      get "/prompt_tracker/prompts", params: { tag: "test-tag" }
      expect(response).to have_http_status(:success)
      expect(response.body).to include(tagged_prompt.name)
    end

    it "filters active prompts" do
      active_prompt = create(:prompt)
      archived_prompt = create(:prompt, :archived)

      get "/prompt_tracker/prompts", params: { status: "active" }
      expect(response).to have_http_status(:success)
      expect(response.body).to include(active_prompt.name)
      expect(response.body).not_to include(archived_prompt.name)
    end

    it "filters archived prompts" do
      active_prompt = create(:prompt)
      archived_prompt = create(:prompt, :archived)

      get "/prompt_tracker/prompts", params: { status: "archived" }
      expect(response).to have_http_status(:success)
      expect(response.body).not_to include(active_prompt.name)
      expect(response.body).to include(archived_prompt.name)
    end

    it "sorts prompts by name" do
      get "/prompt_tracker/prompts", params: { sort: "name" }
      expect(response).to have_http_status(:success)
    end

    it "sorts prompts by calls" do
      get "/prompt_tracker/prompts", params: { sort: "calls" }
      expect(response).to have_http_status(:success)
    end

    it "sorts prompts by cost" do
      get "/prompt_tracker/prompts", params: { sort: "cost" }
      expect(response).to have_http_status(:success)
    end

    it "paginates prompts" do
      create_list(:prompt, 25)

      get "/prompt_tracker/prompts"
      expect(response).to have_http_status(:success)

      get "/prompt_tracker/prompts", params: { page: 2 }
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /prompts/:id" do
    it "shows prompt details" do
      get "/prompt_tracker/prompts/#{prompt.id}"
      expect(response).to have_http_status(:success)
      expect(response.body).to include(prompt.name)
      expect(response.body).to include(prompt.description)
    end

    it "returns 404 for non-existent prompt" do
      get "/prompt_tracker/prompts/999999"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /prompts/:id/analytics" do
    it "shows analytics for prompt" do
      get "/prompt_tracker/prompts/#{prompt.id}/analytics"
      expect(response).to have_http_status(:success)
      expect(response.body).to include(prompt.name)
    end

    it "calculates version stats correctly" do
      version = prompt.active_version
      create(:llm_response, prompt_version: version, cost_usd: 0.01, response_time_ms: 100)

      get "/prompt_tracker/prompts/#{prompt.id}/analytics"
      expect(response).to have_http_status(:success)
      expect(response.body).to include("$0.01")
    end

    it "shows responses over time" do
      version = prompt.active_version
      create(:llm_response, prompt_version: version, created_at: 1.day.ago)
      create(:llm_response, prompt_version: version, created_at: 2.days.ago)

      get "/prompt_tracker/prompts/#{prompt.id}/analytics"
      expect(response).to have_http_status(:success)
    end

    it "shows provider breakdown" do
      version = prompt.active_version
      create(:llm_response, prompt_version: version, provider: "openai")
      create(:llm_response, prompt_version: version, provider: "anthropic")

      get "/prompt_tracker/prompts/#{prompt.id}/analytics"
      expect(response).to have_http_status(:success)
      expect(response.body).to include("openai")
      expect(response.body).to include("anthropic")
    end

    it "shows cost breakdown by provider" do
      version = prompt.active_version
      create(:llm_response, prompt_version: version, provider: "openai", cost_usd: 0.01)
      create(:llm_response, prompt_version: version, provider: "anthropic", cost_usd: 0.02)

      get "/prompt_tracker/prompts/#{prompt.id}/analytics"
      expect(response).to have_http_status(:success)
    end
  end
end
