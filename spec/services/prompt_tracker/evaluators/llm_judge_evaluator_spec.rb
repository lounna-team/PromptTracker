# frozen_string_literal: true

require "rails_helper"
require "ruby_llm/schema"

module PromptTracker
  module Evaluators
    RSpec.describe LlmJudgeEvaluator do
      let(:llm_response) do
        instance_double(
          PromptTracker::LlmResponse,
          rendered_prompt: "What is the capital of France?",
          response_text: "The capital of France is Paris."
        )
      end

      let(:config) do
        {
          judge_model: "gpt-4o-2024-08-06",
          criteria: [ "accuracy", "helpfulness" ],
          score_min: 0,
          score_max: 10
        }
      end

      subject(:evaluator) { described_class.new(llm_response, config) }

      describe "#initialize" do
        it "merges config with defaults" do
          expect(evaluator.config[:judge_model]).to eq("gpt-4o-2024-08-06")
          expect(evaluator.config[:criteria]).to eq([ "accuracy", "helpfulness" ])
          expect(evaluator.config[:score_min]).to eq(0)
          expect(evaluator.config[:score_max]).to eq(10)
        end

        it "uses default values for missing config" do
          minimal_evaluator = described_class.new(llm_response, {})
          expect(minimal_evaluator.config[:judge_model]).to eq("gpt-4o")
          expect(minimal_evaluator.config[:criteria]).to eq(%w[accuracy helpfulness tone])
          expect(minimal_evaluator.config[:score_min]).to eq(0)
          expect(minimal_evaluator.config[:score_max]).to eq(5)
        end

        it "symbolizes string keys in config" do
          string_config = {
            "judge_model" => "gpt-4o",
            "criteria" => [ "clarity" ],
            "score_max" => 100
          }
          evaluator = described_class.new(llm_response, string_config)
          expect(evaluator.config[:judge_model]).to eq("gpt-4o")
          expect(evaluator.config[:criteria]).to eq([ "clarity" ])
          expect(evaluator.config[:score_max]).to eq(100)
        end
      end

      describe "#evaluate" do
        let(:chat_double) { double("RubyLLM::Chat") }
        let(:schema_chat_double) { double("RubyLLM::Chat with schema") }
        let(:response_double) do
          double(
            "RubyLLM::Response",
            content: {
              overall_score: 8.5,
              criteria_scores: { accuracy: 9.0, helpfulness: 8.0 },
              feedback: "Good response"
            },
            raw: double("raw response")
          )
        end

        before do
          # Enable real LLM mode for these tests
          allow(ENV).to receive(:[]).and_call_original
          allow(ENV).to receive(:[]).with("PROMPT_TRACKER_USE_REAL_LLM").and_return("true")

          allow(RubyLLM).to receive(:chat).and_return(chat_double)
          allow(chat_double).to receive(:with_schema).and_return(schema_chat_double)
          allow(schema_chat_double).to receive(:ask).and_return(response_double)
          allow(EvaluationService).to receive(:create_llm_judge).and_return(
            instance_double(Evaluation, score: 8.5)
          )
        end

        it "calls RubyLLM.chat with the judge model" do
          evaluator.evaluate

          expect(RubyLLM).to have_received(:chat).with(model: "gpt-4o-2024-08-06")
        end

        it "calls with_schema with a RubyLLM::Schema class" do
          evaluator.evaluate

          expect(chat_double).to have_received(:with_schema) do |schema_class|
            expect(schema_class).to be < RubyLLM::Schema
          end
        end

        it "calls ask with the judge prompt" do
          evaluator.evaluate

          expect(schema_chat_double).to have_received(:ask) do |prompt|
            expect(prompt).to include("What is the capital of France?")
            expect(prompt).to include("The capital of France is Paris.")
            expect(prompt).to include("accuracy")
            expect(prompt).to include("helpfulness")
          end
        end

        it "creates an LLM judge evaluation with structured response data" do
          evaluator.evaluate

          expect(EvaluationService).to have_received(:create_llm_judge).with(
            hash_including(
              llm_response: llm_response,
              judge_model: "gpt-4o-2024-08-06",
              score: 8.5,
              score_min: 0,
              score_max: 10,
              criteria_scores: { accuracy: 9.0, helpfulness: 8.0 },
              feedback: "Good response"
            )
          )
        end

        it "includes metadata about structured output usage" do
          evaluator.evaluate

          expect(EvaluationService).to have_received(:create_llm_judge).with(
            hash_including(
              metadata: hash_including(
                used_structured_output: true,
                judge_model: "gpt-4o-2024-08-06",
                criteria: [ "accuracy", "helpfulness" ],
                mock_mode: false
              )
            )
          )
        end

        it "returns the evaluation" do
          result = evaluator.evaluate

          expect(result).to respond_to(:score)
          expect(result.score).to eq(8.5)
        end

        context "when RubyLLM raises an error" do
          before do
            allow(schema_chat_double).to receive(:ask).and_raise(StandardError.new("API error"))
          end

          it "raises the error" do
            expect { evaluator.evaluate }.to raise_error(StandardError, /API error/)
          end
        end

        context "when in mock mode" do
          before do
            allow(ENV).to receive(:[]).and_call_original
            allow(ENV).to receive(:[]).with("PROMPT_TRACKER_USE_REAL_LLM").and_return(nil)
          end

          it "does not call RubyLLM" do
            evaluator.evaluate

            expect(RubyLLM).not_to have_received(:chat)
          end

          it "generates mock evaluation data" do
            evaluator.evaluate

            expect(EvaluationService).to have_received(:create_llm_judge).with(
              hash_including(
                llm_response: llm_response,
                judge_model: "gpt-4o-2024-08-06",
                score_min: 0,
                score_max: 10,
                feedback: /MOCK EVALUATION/
              )
            )
          end

          it "includes mock_mode flag in metadata" do
            evaluator.evaluate

            expect(EvaluationService).to have_received(:create_llm_judge).with(
              hash_including(
                metadata: hash_including(
                  mock_mode: true
                )
              )
            )
          end

          it "generates scores within configured range" do
            evaluation = evaluator.evaluate

            # The mock should generate scores within the configured range
            expect(EvaluationService).to have_received(:create_llm_judge) do |args|
              score = args[:score]
              expect(score).to be_between(0, 10).inclusive
            end
          end
        end
      end

      describe "#build_judge_prompt" do
        it "includes the original prompt" do
          prompt = evaluator.send(:build_judge_prompt)

          expect(prompt).to include("What is the capital of France?")
        end

        it "includes the response to evaluate" do
          prompt = evaluator.send(:build_judge_prompt)

          expect(prompt).to include("The capital of France is Paris.")
        end

        it "includes evaluation criteria" do
          prompt = evaluator.send(:build_judge_prompt)

          expect(prompt).to include("accuracy")
          expect(prompt).to include("helpfulness")
        end

        it "includes score range" do
          prompt = evaluator.send(:build_judge_prompt)

          expect(prompt).to include("0")
          expect(prompt).to include("10")
        end

        it "mentions structured JSON output" do
          prompt = evaluator.send(:build_judge_prompt)

          expect(prompt).to include("structured as JSON")
        end

        it "includes custom instructions when provided" do
          custom_config = config.merge(custom_instructions: "Focus on technical accuracy")
          custom_evaluator = described_class.new(llm_response, custom_config)

          prompt = custom_evaluator.send(:build_judge_prompt)

          expect(prompt).to include("Focus on technical accuracy")
        end
      end

      describe "#build_schema" do
        it "returns a RubyLLM::Schema subclass" do
          schema = evaluator.send(:build_schema)

          expect(schema).to be < RubyLLM::Schema
        end

        it "uses LlmJudgeSchema.for_criteria" do
          allow(LlmJudgeSchema).to receive(:for_criteria).and_call_original

          evaluator.send(:build_schema)

          expect(LlmJudgeSchema).to have_received(:for_criteria).with(
            criteria: [ "accuracy", "helpfulness" ],
            score_min: 0,
            score_max: 10
          )
        end
      end
    end
  end
end
