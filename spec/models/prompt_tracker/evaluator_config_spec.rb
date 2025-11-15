# frozen_string_literal: true

require "rails_helper"

RSpec.describe PromptTracker::EvaluatorConfig, type: :model do
  describe "associations" do
    it { should belong_to(:prompt).class_name("PromptTracker::Prompt") }
  end

  describe "validations" do
    subject { build(:evaluator_config) }

    it { should validate_presence_of(:evaluator_key) }
    it { should validate_presence_of(:run_mode) }
    it { should validate_presence_of(:priority) }
    it { should validate_presence_of(:weight) }

    it { should validate_inclusion_of(:run_mode).in_array(%w[sync async]) }
    it { should validate_numericality_of(:priority).only_integer }
    it { should validate_numericality_of(:weight).is_greater_than_or_equal_to(0) }

    describe "uniqueness of evaluator_key" do
      it "validates uniqueness scoped to prompt_id" do
        prompt = create(:prompt)
        create(:evaluator_config, prompt: prompt, evaluator_key: "test_evaluator")

        duplicate = build(:evaluator_config, prompt: prompt, evaluator_key: "test_evaluator")
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:evaluator_key]).to include("has already been taken")
      end

      it "allows same evaluator_key for different prompts" do
        prompt1 = create(:prompt)
        prompt2 = create(:prompt)

        create(:evaluator_config, prompt: prompt1, evaluator_key: "test_evaluator")
        duplicate = build(:evaluator_config, prompt: prompt2, evaluator_key: "test_evaluator")

        expect(duplicate).to be_valid
      end
    end

    describe "min_dependency_score validation" do
      it { should validate_numericality_of(:min_dependency_score)
        .only_integer
        .is_greater_than_or_equal_to(0)
        .is_less_than_or_equal_to(100)
        .allow_nil }
    end

    describe "dependency_exists validation" do
      it "is valid when depends_on references an existing evaluator" do
        prompt = create(:prompt)
        create(:evaluator_config, prompt: prompt, evaluator_key: "base_evaluator")
        dependent = build(:evaluator_config, prompt: prompt, evaluator_key: "dependent", depends_on: "base_evaluator")

        expect(dependent).to be_valid
      end

      it "is invalid when depends_on references a non-existent evaluator" do
        prompt = create(:prompt)
        dependent = build(:evaluator_config, prompt: prompt, evaluator_key: "dependent", depends_on: "non_existent")

        expect(dependent).not_to be_valid
        expect(dependent.errors[:depends_on]).to include("evaluator 'non_existent' must be configured for this prompt")
      end
    end

    describe "no_circular_dependencies validation" do
      it "is invalid when creating a circular dependency" do
        prompt = create(:prompt)
        config_a = create(:evaluator_config, prompt: prompt, evaluator_key: "eval_a", depends_on: nil)
        create(:evaluator_config, prompt: prompt, evaluator_key: "eval_b", depends_on: "eval_a")

        # Try to make eval_a depend on eval_b (creating a circle)
        config_a.depends_on = "eval_b"

        expect(config_a).not_to be_valid
        expect(config_a.errors[:depends_on]).to include("creates a circular dependency")
      end

      it "is invalid when creating a longer circular dependency chain" do
        prompt = create(:prompt)
        config_a = create(:evaluator_config, prompt: prompt, evaluator_key: "eval_a")
        create(:evaluator_config, prompt: prompt, evaluator_key: "eval_b", depends_on: "eval_a")
        create(:evaluator_config, prompt: prompt, evaluator_key: "eval_c", depends_on: "eval_b")

        # Try to make eval_a depend on eval_c (creating a circle: a -> b -> c -> a)
        config_a.depends_on = "eval_c"

        expect(config_a).not_to be_valid
        expect(config_a.errors[:depends_on]).to include("creates a circular dependency")
      end
    end
  end

  describe "scopes" do
    let(:prompt) { create(:prompt) }

    describe ".enabled" do
      it "returns only enabled configs" do
        enabled1 = create(:evaluator_config, prompt: prompt, enabled: true)
        enabled2 = create(:evaluator_config, prompt: prompt, enabled: true, evaluator_key: "other")
        create(:evaluator_config, :disabled, prompt: prompt, evaluator_key: "disabled")

        expect(described_class.enabled).to contain_exactly(enabled1, enabled2)
      end
    end

    describe ".by_priority" do
      it "orders configs by priority descending" do
        low = create(:evaluator_config, :low_priority, prompt: prompt)
        high = create(:evaluator_config, :high_priority, prompt: prompt, evaluator_key: "high")
        medium = create(:evaluator_config, prompt: prompt, evaluator_key: "medium", priority: 100)

        expect(described_class.by_priority).to eq([ high, medium, low ])
      end
    end

    describe ".independent" do
      it "returns configs with no dependencies" do
        independent1 = create(:evaluator_config, prompt: prompt, evaluator_key: "length_check", depends_on: nil)
        independent2 = create(:evaluator_config, prompt: prompt, evaluator_key: "format_check", depends_on: nil)
        create(:evaluator_config, prompt: prompt, evaluator_key: "keyword_check", depends_on: "length_check")

        expect(described_class.independent).to contain_exactly(independent1, independent2)
      end
    end

    describe ".dependent" do
      it "returns configs with dependencies" do
        create(:evaluator_config, prompt: prompt, depends_on: nil)
        create(:evaluator_config, prompt: prompt, evaluator_key: "base", depends_on: nil)
        dependent = create(:evaluator_config, prompt: prompt, evaluator_key: "dependent", depends_on: "base")

        expect(described_class.dependent).to contain_exactly(dependent)
      end
    end
  end

  describe "instance methods" do
    let(:prompt) { create(:prompt) }
    let(:config) { create(:evaluator_config, prompt: prompt, evaluator_key: "keyword_check") }

    describe "#sync?" do
      it "returns true when run_mode is sync" do
        config.run_mode = "sync"
        expect(config.sync?).to be true
      end

      it "returns false when run_mode is async" do
        config.run_mode = "async"
        expect(config.sync?).to be false
      end
    end

    describe "#async?" do
      it "returns true when run_mode is async" do
        config.run_mode = "async"
        expect(config.async?).to be true
      end

      it "returns false when run_mode is sync" do
        config.run_mode = "sync"
        expect(config.async?).to be false
      end
    end

    describe "#has_dependency?" do
      it "returns true when depends_on is present" do
        config.depends_on = "other_evaluator"
        expect(config.has_dependency?).to be true
      end

      it "returns false when depends_on is nil" do
        config.depends_on = nil
        expect(config.has_dependency?).to be false
      end
    end

    describe "#dependency_met?" do
      let(:response) { create(:llm_response) }

      context "when config has no dependency" do
        it "returns true" do
          config.depends_on = nil
          expect(config.dependency_met?(response)).to be true
        end
      end

      context "when config has a dependency" do
        before do
          # Create a dependency config using a real evaluator from the registry
          create(:evaluator_config, prompt: prompt, evaluator_key: "length_check")
          config.update!(depends_on: "length_check", min_dependency_score: 80)
        end

        it "returns false when dependency evaluation doesn't exist" do
          expect(config.dependency_met?(response)).to be false
        end

        it "returns true when dependency score meets minimum" do
          # Use the actual evaluator_id that length_check evaluator uses
          create(:evaluation, llm_response: response, evaluator_id: "length_evaluator_v1", score: 85, score_max: 100)
          expect(config.dependency_met?(response)).to be true
        end

        it "returns false when dependency score is below minimum" do
          create(:evaluation, llm_response: response, evaluator_id: "length_evaluator_v1", score: 75, score_max: 100)
          expect(config.dependency_met?(response)).to be false
        end

        it "uses default min_dependency_score of 80 when not specified" do
          config.update!(min_dependency_score: nil)

          # Test with score below default threshold (80)
          create(:evaluation, llm_response: response, evaluator_id: "length_evaluator_v1", score: 79, score_max: 100)
          expect(config.dependency_met?(response)).to be false

          # Update the evaluation to meet the threshold
          response.evaluations.find_by(evaluator_id: "length_evaluator_v1").update!(score: 80)
          expect(config.dependency_met?(response)).to be true
        end
      end
    end

    describe "#normalized_weight" do
      it "returns weight normalized to total of all enabled configs" do
        config.update!(weight: 1.0, enabled: true)
        create(:evaluator_config, prompt: prompt, evaluator_key: "other1", weight: 2.0, enabled: true)
        create(:evaluator_config, prompt: prompt, evaluator_key: "other2", weight: 1.0, enabled: true)
        create(:evaluator_config, :disabled, prompt: prompt, evaluator_key: "disabled", weight: 10.0)

        # Total enabled weight: 1.0 + 2.0 + 1.0 = 4.0
        # This config's normalized weight: 1.0 / 4.0 = 0.25
        expect(config.normalized_weight).to eq(0.25)
      end

      it "returns 0 when total weight is 0" do
        config.update!(weight: 0, enabled: true)
        expect(config.normalized_weight).to eq(0)
      end
    end

    describe "#name" do
      it "returns titleized evaluator_key when metadata not available" do
        config.evaluator_key = "my_custom_evaluator"
        allow(config).to receive(:evaluator_metadata).and_return(nil)

        expect(config.name).to eq("My Custom Evaluator")
      end

      it "returns name from metadata when available" do
        allow(config).to receive(:evaluator_metadata).and_return({ name: "Custom Name" })
        expect(config.name).to eq("Custom Name")
      end
    end

    describe "#description" do
      it "returns description from metadata when available" do
        allow(config).to receive(:evaluator_metadata).and_return({ description: "Test description" })
        expect(config.description).to eq("Test description")
      end

      it "returns nil when metadata not available" do
        allow(config).to receive(:evaluator_metadata).and_return(nil)
        expect(config.description).to be_nil
      end
    end
  end
end
