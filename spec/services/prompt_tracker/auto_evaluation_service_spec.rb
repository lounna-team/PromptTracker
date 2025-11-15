# frozen_string_literal: true

require "rails_helper"

RSpec.describe PromptTracker::AutoEvaluationService do
  let(:prompt) { create(:prompt) }
  let(:version) { create(:prompt_version, prompt: prompt) }
  let(:llm_response) { create(:llm_response, prompt_version: version) }

  describe ".evaluate" do
    it "creates a new instance and calls evaluate" do
      service = instance_double(described_class)
      allow(described_class).to receive(:new).with(llm_response).and_return(service)
      allow(service).to receive(:evaluate)

      described_class.evaluate(llm_response)

      expect(service).to have_received(:evaluate)
    end
  end

  describe "#evaluate" do
    context "when prompt has no evaluator configs" do
      it "does not run any evaluations" do
        expect {
          described_class.evaluate(llm_response)
        }.not_to change(PromptTracker::Evaluation, :count)
      end
    end

    context "when prompt has independent evaluator configs" do
      let!(:config1) { create(:evaluator_config, prompt: prompt, evaluator_key: "length_check", priority: 100) }
      let!(:config2) { create(:evaluator_config, prompt: prompt, evaluator_key: "keyword_check", priority: 200) }

      it "runs evaluators in priority order" do
        service = described_class.new(llm_response)
        expect(service).to receive(:run_evaluation).with(config2).ordered.and_call_original
        expect(service).to receive(:run_evaluation).with(config1).ordered.and_call_original

        service.evaluate
      end

      it "runs all independent evaluators" do
        # Note: Each evaluator may create multiple evaluations, so we just verify some were created
        expect {
          described_class.evaluate(llm_response)
        }.to change(PromptTracker::Evaluation, :count).by_at_least(2)
      end
    end

    context "when prompt has dependent evaluator configs" do
      let!(:base_config) { create(:evaluator_config, prompt: prompt, evaluator_key: "length_check", priority: 100) }
      let!(:dependent_config) do
        create(:evaluator_config, prompt: prompt, evaluator_key: "keyword_check", depends_on: "length_check", min_dependency_score: 50, priority: 50)
      end

      it "runs dependent evaluator only if dependency is met" do
        # The length_check evaluator will run first and create an evaluation
        # Then keyword_check should run because the dependency is met
        initial_count = PromptTracker::Evaluation.count
        described_class.evaluate(llm_response)

        # Verify both evaluators ran (they may create multiple evaluations each)
        expect(PromptTracker::Evaluation.count).to be > initial_count
        evaluator_ids = llm_response.evaluations.pluck(:evaluator_id).uniq
        expect(evaluator_ids).to include("length_evaluator_v1")
        expect(evaluator_ids).to include("keyword_evaluator_v1")
      end

      it "skips dependent evaluator if dependency is not met" do
        # Set a very high min_dependency_score that won't be met
        dependent_config.update!(min_dependency_score: 99)

        # Only the base evaluator should run
        initial_count = PromptTracker::Evaluation.count
        described_class.evaluate(llm_response)

        # Verify only base evaluation was created
        evaluator_ids = llm_response.evaluations.pluck(:evaluator_id).uniq
        expect(evaluator_ids).to include("length_evaluator_v1")
        expect(evaluator_ids).not_to include("keyword_evaluator_v1")
      end
    end

    context "when evaluator config is disabled" do
      let!(:disabled_config) { create(:evaluator_config, :disabled, prompt: prompt) }

      it "does not run disabled evaluators" do
        expect {
          described_class.evaluate(llm_response)
        }.not_to change(PromptTracker::Evaluation, :count)
      end
    end

    context "when evaluator config is async" do
      let!(:async_config) { create(:evaluator_config, :async, prompt: prompt) }

      it "schedules a background job instead of running immediately" do
        expect(PromptTracker::EvaluationJob).to receive(:perform_later).with(
          llm_response.id,
          async_config.id,
          check_dependency: false
        )

        described_class.evaluate(llm_response)
      end
    end

    context "when sync evaluation fails" do
      let!(:config) { create(:evaluator_config, prompt: prompt) }

      it "logs error and continues with other evaluators" do
        allow_any_instance_of(PromptTracker::EvaluatorConfig).to receive(:build_evaluator).and_raise(StandardError, "Test error")
        allow(Rails.logger).to receive(:error)

        expect {
          described_class.evaluate(llm_response)
        }.not_to raise_error

        expect(Rails.logger).to have_received(:error).with(/Sync evaluation failed/).at_least(:once)
      end
    end

    context "when async evaluation scheduling fails" do
      let!(:async_config) { create(:evaluator_config, :async, prompt: prompt) }

      it "logs error and continues" do
        allow(PromptTracker::EvaluationJob).to receive(:perform_later).and_raise(StandardError, "Job error")
        allow(Rails.logger).to receive(:error)

        expect {
          described_class.evaluate(llm_response)
        }.not_to raise_error

        expect(Rails.logger).to have_received(:error).with(/Failed to schedule async evaluation/).at_least(:once)
      end
    end
  end
end
