# frozen_string_literal: true

require "rails_helper"

RSpec.describe PromptTracker::Evaluators::HumanEvaluator do
  let(:prompt) { create(:prompt, :with_active_version) }
  let(:version) { prompt.active_version }
  let(:llm_response) { create(:llm_response, prompt_version: version, response_text: "Test response") }

  describe "#evaluate" do
    context "with complete configuration" do
      let(:config) do
        {
          evaluator_id: "john@example.com",
          score: 4.5,
          score_min: 0,
          score_max: 5,
          feedback: "Great response!",
          evaluation_context: "manual"
        }
      end

      let(:evaluator) { described_class.new(llm_response, config) }

      it "creates a human evaluation" do
        expect {
          evaluator.evaluate
        }.to change(PromptTracker::Evaluation, :count).by(1)
      end

      it "sets the correct evaluator type" do
        evaluation = evaluator.evaluate

        expect(evaluation.evaluator_type).to eq("human")
      end

      it "uses the provided evaluator_id" do
        evaluation = evaluator.evaluate

        expect(evaluation.evaluator_id).to eq("john@example.com")
      end

      it "uses the provided score" do
        evaluation = evaluator.evaluate

        expect(evaluation.score).to eq(4.5)
      end

      it "uses the provided score range" do
        evaluation = evaluator.evaluate

        expect(evaluation.score_min).to eq(0)
        expect(evaluation.score_max).to eq(5)
      end

      it "uses the provided feedback" do
        evaluation = evaluator.evaluate

        expect(evaluation.feedback).to eq("Great response!")
      end

      it "uses the provided evaluation context" do
        evaluation = evaluator.evaluate

        expect(evaluation.evaluation_context).to eq("manual")
      end

      it "associates the evaluation with the llm_response" do
        evaluation = evaluator.evaluate

        expect(evaluation.llm_response).to eq(llm_response)
      end
    end

    context "with minimal configuration" do
      let(:config) do
        {
          score: 3.0
        }
      end

      let(:evaluator) { described_class.new(llm_response, config) }

      it "creates an evaluation with defaults" do
        evaluation = evaluator.evaluate

        expect(evaluation.evaluator_id).to eq("unknown")
        expect(evaluation.score_min).to eq(0)
        expect(evaluation.score_max).to eq(5)
        expect(evaluation.evaluation_context).to eq("manual")
      end
    end

    context "with missing evaluator_id" do
      let(:config) do
        {
          score: 4.0,
          feedback: "Good"
        }
      end

      let(:evaluator) { described_class.new(llm_response, config) }

      it "uses 'unknown' as default evaluator_id" do
        evaluation = evaluator.evaluate

        expect(evaluation.evaluator_id).to eq("unknown")
      end
    end
  end

  describe "#evaluate_score" do
    let(:evaluator) { described_class.new(llm_response, {}) }

    it "raises NotImplementedError" do
      expect {
        evaluator.evaluate_score
      }.to raise_error(NotImplementedError, "Human evaluator doesn't calculate scores")
    end
  end

  describe "#evaluator_id" do
    context "when evaluator_id is provided in config" do
      let(:config) { { evaluator_id: "jane@example.com" } }
      let(:evaluator) { described_class.new(llm_response, config) }

      it "returns the configured evaluator_id" do
        expect(evaluator.evaluator_id).to eq("jane@example.com")
      end
    end

    context "when evaluator_id is not provided" do
      let(:evaluator) { described_class.new(llm_response, {}) }

      it "returns 'human' as default" do
        expect(evaluator.evaluator_id).to eq("human")
      end
    end
  end
end

