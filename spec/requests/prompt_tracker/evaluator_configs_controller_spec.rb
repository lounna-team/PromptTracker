# frozen_string_literal: true

require "rails_helper"

RSpec.describe "PromptTracker::EvaluatorConfigsController", type: :request do
  let(:prompt) { create(:prompt) }
  let(:evaluator_config) do
    create(:evaluator_config,
           prompt: prompt,
           evaluator_key: "length_check",
           config: { min_length: 10, max_length: 100 })
  end

  describe "GET /evaluator_configs/config_form" do
    it "returns config form for evaluator" do
      get "/prompt_tracker/evaluator_configs/config_form", params: { evaluator_key: "length_check" }
      expect(response).to have_http_status(:success)
    end

    it "returns 404 for non-existent evaluator config form" do
      get "/prompt_tracker/evaluator_configs/config_form", params: { evaluator_key: "non_existent" }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /prompts/:prompt_id/evaluators" do
    it "returns JSON with configs and available evaluators" do
      evaluator_config # create it
      get "/prompt_tracker/prompts/#{prompt.id}/evaluators", headers: { "Accept" => "application/json" }
      expect(response).to have_http_status(:success)

      json = JSON.parse(response.body)
      expect(json).to have_key("configs")
      expect(json).to have_key("available")
    end

    it "orders configs by priority" do
      config1 = create(:evaluator_config, prompt: prompt, evaluator_key: "keyword_check", priority: 50)
      config2 = create(:evaluator_config, prompt: prompt, evaluator_key: "format_check", priority: 150)
      config3 = create(:evaluator_config, prompt: prompt, evaluator_key: "length_check", priority: 100)

      get "/prompt_tracker/prompts/#{prompt.id}/evaluators", headers: { "Accept" => "application/json" }
      expect(response).to have_http_status(:success)

      json = JSON.parse(response.body)
      config_ids = json["configs"].map { |c| c["id"] }
      expect(config_ids).to eq([config2.id, config3.id, config1.id])
    end
  end

  describe "GET /prompts/:prompt_id/evaluators/:id" do
    it "returns evaluator config as JSON" do
      get "/prompt_tracker/prompts/#{prompt.id}/evaluators/#{evaluator_config.id}", headers: { "Accept" => "application/json" }
      expect(response).to have_http_status(:success)

      json = JSON.parse(response.body)
      expect(json["id"]).to eq(evaluator_config.id)
      expect(json["evaluator_key"]).to eq("length_check")
    end

    it "returns 404 for non-existent config" do
      get "/prompt_tracker/prompts/#{prompt.id}/evaluators/999999", headers: { "Accept" => "application/json" }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /prompts/:prompt_id/evaluators" do
    it "creates evaluator config" do
      expect {
        post "/prompt_tracker/prompts/#{prompt.id}/evaluators", params: {
          evaluator_config: {
            evaluator_key: "keyword_check",
            enabled: true,
            run_mode: "sync",
            priority: 100,
            weight: 1.0,
            config: { required_keywords: ["hello", "world"] }
          }
        }
      }.to change(PromptTracker::EvaluatorConfig, :count).by(1)

      expect(response).to redirect_to("/prompt_tracker/prompts/#{prompt.id}")
      follow_redirect!
      expect(response.body).to include("Evaluator configured successfully")
    end

    it "creates evaluator config as JSON" do
      expect {
        post "/prompt_tracker/prompts/#{prompt.id}/evaluators",
             params: {
               evaluator_config: {
                 evaluator_key: "keyword_check",
                 enabled: true,
                 run_mode: "sync",
                 priority: 100,
                 weight: 1.0
               }
             },
             headers: { "Accept" => "application/json" }
      }.to change(PromptTracker::EvaluatorConfig, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["evaluator_key"]).to eq("keyword_check")
    end

    it "processes config params correctly" do
      post "/prompt_tracker/prompts/#{prompt.id}/evaluators", params: {
        evaluator_config: {
          evaluator_key: "keyword_check",
          enabled: true,
          run_mode: "sync",
          priority: 100,
          weight: 1.0,
          config: {
            required_keywords: "hello\nworld\n",
            case_sensitive: "true"
          }
        }
      }

      config = PromptTracker::EvaluatorConfig.last
      expect(config.config["required_keywords"]).to eq(["hello", "world"])
      expect(config.config["case_sensitive"]).to eq(true)
    end

    it "handles invalid evaluator config" do
      expect {
        post "/prompt_tracker/prompts/#{prompt.id}/evaluators", params: {
          evaluator_config: {
            evaluator_key: "", # Invalid - blank
            enabled: true,
            run_mode: "sync",
            priority: 100,
            weight: 1.0
          }
        }
      }.not_to change(PromptTracker::EvaluatorConfig, :count)

      expect(response).to redirect_to("/prompt_tracker/prompts/#{prompt.id}")
      follow_redirect!
      expect(response.body).to include("Failed to configure evaluator")
    end

    it "handles invalid evaluator config as JSON" do
      expect {
        post "/prompt_tracker/prompts/#{prompt.id}/evaluators",
             params: {
               evaluator_config: {
                 evaluator_key: "",
                 enabled: true,
                 run_mode: "sync",
                 priority: 100,
                 weight: 1.0
               }
             },
             headers: { "Accept" => "application/json" }
      }.not_to change(PromptTracker::EvaluatorConfig, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json).to have_key("errors")
    end
  end

  describe "PATCH /prompts/:prompt_id/evaluators/:id" do
    it "updates evaluator config" do
      patch "/prompt_tracker/prompts/#{prompt.id}/evaluators/#{evaluator_config.id}", params: {
        evaluator_config: {
          priority: 200,
          config: { min_length: 20, max_length: 200 }
        }
      }

      expect(response).to redirect_to("/prompt_tracker/prompts/#{prompt.id}")
      follow_redirect!
      expect(response.body).to include("Evaluator updated successfully")

      evaluator_config.reload
      expect(evaluator_config.priority).to eq(200)
      expect(evaluator_config.config["min_length"]).to eq(20)
    end

    it "updates evaluator config as JSON" do
      patch "/prompt_tracker/prompts/#{prompt.id}/evaluators/#{evaluator_config.id}",
            params: { evaluator_config: { priority: 200 } },
            headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["priority"]).to eq(200)
    end

    it "handles invalid update" do
      patch "/prompt_tracker/prompts/#{prompt.id}/evaluators/#{evaluator_config.id}", params: {
        evaluator_config: { evaluator_key: "" } # Invalid - blank evaluator_key
      }

      expect(response).to redirect_to("/prompt_tracker/prompts/#{prompt.id}")
      follow_redirect!
      expect(response.body).to include("Failed to update evaluator")
    end

    it "handles invalid update as JSON" do
      patch "/prompt_tracker/prompts/#{prompt.id}/evaluators/#{evaluator_config.id}",
            params: { evaluator_config: { evaluator_key: "" } },
            headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json).to have_key("errors")
    end
  end

  describe "DELETE /prompts/:prompt_id/evaluators/:id" do
    it "destroys evaluator config" do
      evaluator_config # create it first

      expect {
        delete "/prompt_tracker/prompts/#{prompt.id}/evaluators/#{evaluator_config.id}"
      }.to change(PromptTracker::EvaluatorConfig, :count).by(-1)

      expect(response).to redirect_to("/prompt_tracker/prompts/#{prompt.id}")
      follow_redirect!
      expect(response.body).to include("Evaluator removed successfully")
    end

    it "destroys evaluator config as JSON" do
      evaluator_config # create it first

      expect {
        delete "/prompt_tracker/prompts/#{prompt.id}/evaluators/#{evaluator_config.id}",
               headers: { "Accept" => "application/json" }
      }.to change(PromptTracker::EvaluatorConfig, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end

  describe "config processing" do
    it "processes required_keywords from textarea" do
      post "/prompt_tracker/prompts/#{prompt.id}/evaluators", params: {
        evaluator_config: {
          evaluator_key: "keyword_check",
          enabled: true,
          run_mode: "sync",
          priority: 100,
          weight: 1.0,
          config: {
            required_keywords: "hello\nworld\ntest\n"
          }
        }
      }

      config = PromptTracker::EvaluatorConfig.last
      expect(config.config["required_keywords"]).to eq(["hello", "world", "test"])
    end

    it "processes forbidden_keywords from textarea" do
      post "/prompt_tracker/prompts/#{prompt.id}/evaluators", params: {
        evaluator_config: {
          evaluator_key: "keyword_check",
          enabled: true,
          run_mode: "sync",
          priority: 100,
          weight: 1.0,
          config: {
            forbidden_keywords: "bad\nworse\n"
          }
        }
      }

      config = PromptTracker::EvaluatorConfig.last
      expect(config.config["forbidden_keywords"]).to eq(["bad", "worse"])
    end

    it "processes boolean values" do
      post "/prompt_tracker/prompts/#{prompt.id}/evaluators", params: {
        evaluator_config: {
          evaluator_key: "keyword_check",
          enabled: true,
          run_mode: "sync",
          priority: 100,
          weight: 1.0,
          config: {
            case_sensitive: "true",
            strict: "false"
          }
        }
      }

      config = PromptTracker::EvaluatorConfig.last
      expect(config.config["case_sensitive"]).to eq(true)
      expect(config.config["strict"]).to eq(false)
    end

    it "processes integer values" do
      post "/prompt_tracker/prompts/#{prompt.id}/evaluators", params: {
        evaluator_config: {
          evaluator_key: "length_check",
          enabled: true,
          run_mode: "sync",
          priority: 100,
          weight: 1.0,
          config: {
            min_length: "10",
            max_length: "100"
          }
        }
      }

      config = PromptTracker::EvaluatorConfig.last
      expect(config.config["min_length"]).to eq(10)
      expect(config.config["max_length"]).to eq(100)
    end

    it "processes JSON schema" do
      schema = { type: "object", properties: { name: { type: "string" } } }

      post "/prompt_tracker/prompts/#{prompt.id}/evaluators", params: {
        evaluator_config: {
          evaluator_key: "format_check",
          enabled: true,
          run_mode: "sync",
          priority: 100,
          weight: 1.0,
          config: {
            schema: schema.to_json
          }
        }
      }

      config = PromptTracker::EvaluatorConfig.last
      expect(config.config["schema"]).to eq(schema.deep_stringify_keys)
    end

    it "handles invalid JSON schema gracefully" do
      post "/prompt_tracker/prompts/#{prompt.id}/evaluators", params: {
        evaluator_config: {
          evaluator_key: "format_check",
          enabled: true,
          run_mode: "sync",
          priority: 100,
          weight: 1.0,
          config: {
            schema: "invalid json {"
          }
        }
      }

      config = PromptTracker::EvaluatorConfig.last
      expect(config.config["schema"]).to be_nil
    end
  end
end
