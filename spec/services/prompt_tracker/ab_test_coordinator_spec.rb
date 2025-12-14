# frozen_string_literal: true

require "rails_helper"

RSpec.describe PromptTracker::AbTestCoordinator do
  let(:prompt) { create(:prompt, :with_active_version) }
  let(:active_version) { prompt.active_version }

  describe ".select_version_for_prompt" do
    context "when prompt does not exist" do
      it "returns nil" do
        result = described_class.select_version_for_prompt("non_existent")
        expect(result).to be_nil
      end
    end

    context "when no A/B test is running" do
      it "returns the active version with no ab_test or variant" do
        result = described_class.select_version_for_prompt(prompt.name)

        expect(result[:version]).to eq(active_version)
        expect(result[:ab_test]).to be_nil
        expect(result[:variant]).to be_nil
      end
    end

    context "when A/B test is running" do
      let(:version_a) { create(:prompt_version, prompt: prompt, version_number: 2) }
      let(:version_b) { create(:prompt_version, prompt: prompt, version_number: 3) }
      let!(:ab_test) do
        create(:ab_test, :running, prompt: prompt, version_a: version_a, version_b: version_b)
      end

      it "returns a version from the A/B test" do
        result = described_class.select_version_for_prompt(prompt.name)

        expect(result[:version]).to be_in([ version_a, version_b ])
        expect(result[:ab_test]).to eq(ab_test)
        expect(result[:variant]).to be_in(%w[A B])
      end

      it "respects traffic split distribution" do
        # Run multiple times to check distribution
        variants = 100.times.map do
          result = described_class.select_version_for_prompt(prompt.name)
          result[:variant]
        end

        # Should have both variants selected at least once
        expect(variants).to include("A")
        expect(variants).to include("B")
      end
    end

    context "when multiple A/B tests exist but only one is running" do
      # Note: prompt already has version 1 from :with_active_version
      # Previous context uses versions 2 and 3
      # So we start from version 4 here
      let(:version_c) { create(:prompt_version, prompt: prompt, version_number: 4) }
      let(:version_d) { create(:prompt_version, prompt: prompt, version_number: 5) }
      let(:version_e) { create(:prompt_version, prompt: prompt, version_number: 6) }
      let(:version_f) { create(:prompt_version, prompt: prompt, version_number: 7) }
      let(:version_g) { create(:prompt_version, prompt: prompt, version_number: 8) }
      let(:version_h) { create(:prompt_version, prompt: prompt, version_number: 9) }

      let!(:draft_test) { create(:ab_test, prompt: prompt, status: "draft", version_a: version_c, version_b: version_d) }
      let!(:running_test) do
        create(:ab_test, :running, prompt: prompt, version_a: version_e, version_b: version_f, name: "Running Test")
      end
      let!(:completed_test) { create(:ab_test, :completed, prompt: prompt, version_a: version_g, version_b: version_h, name: "Completed Test") }

      it "uses the running test" do
        result = described_class.select_version_for_prompt(prompt.name)

        expect(result[:ab_test]).to eq(running_test)
      end
    end
  end

  describe ".select_version_for" do
    context "when prompt is nil" do
      it "returns nil" do
        result = described_class.select_version_for(nil)
        expect(result).to be_nil
      end
    end

    context "when no A/B test is running" do
      it "returns the active version" do
        result = described_class.select_version_for(prompt)

        expect(result[:version]).to eq(active_version)
        expect(result[:ab_test]).to be_nil
        expect(result[:variant]).to be_nil
      end
    end

    context "when A/B test is running" do
      let(:version_a) { create(:prompt_version, prompt: prompt, version_number: 2) }
      let(:version_b) { create(:prompt_version, prompt: prompt, version_number: 3) }
      let!(:ab_test) do
        create(:ab_test, :running, prompt: prompt, version_a: version_a, version_b: version_b)
      end

      it "returns a version from the A/B test" do
        result = described_class.select_version_for(prompt)

        expect(result[:version]).to be_in([ version_a, version_b ])
        expect(result[:ab_test]).to eq(ab_test)
        expect(result[:variant]).to be_in(%w[A B])
      end
    end
  end

  describe ".ab_test_running?" do
    context "when prompt does not exist" do
      it "returns false" do
        expect(described_class.ab_test_running?("non_existent")).to be false
      end
    end

    context "when no A/B test is running" do
      it "returns false" do
        expect(described_class.ab_test_running?(prompt.name)).to be false
      end
    end

    context "when A/B test is running" do
      let!(:ab_test) { create(:ab_test, :running, prompt: prompt) }

      it "returns true" do
        expect(described_class.ab_test_running?(prompt.name)).to be true
      end
    end

    context "when A/B test exists but is not running" do
      let!(:ab_test) { create(:ab_test, prompt: prompt, status: "draft") }

      it "returns false" do
        expect(described_class.ab_test_running?(prompt.name)).to be false
      end
    end
  end

  describe ".get_running_test" do
    context "when prompt does not exist" do
      it "returns nil" do
        expect(described_class.get_running_test("non_existent")).to be_nil
      end
    end

    context "when no A/B test is running" do
      it "returns nil" do
        expect(described_class.get_running_test(prompt.name)).to be_nil
      end
    end

    context "when A/B test is running" do
      let!(:ab_test) { create(:ab_test, :running, prompt: prompt) }

      it "returns the running test" do
        expect(described_class.get_running_test(prompt.name)).to eq(ab_test)
      end
    end
  end

  describe ".valid_variant?" do
    let(:ab_test) { create(:ab_test, prompt: prompt) }

    context "when ab_test is nil" do
      it "returns false" do
        expect(described_class.valid_variant?(nil, "A")).to be false
      end
    end

    context "when variant_name is nil" do
      it "returns false" do
        expect(described_class.valid_variant?(ab_test, nil)).to be false
      end
    end

    context "when variant exists in test" do
      it "returns true" do
        expect(described_class.valid_variant?(ab_test, "A")).to be true
        expect(described_class.valid_variant?(ab_test, "B")).to be true
      end
    end

    context "when variant does not exist in test" do
      it "returns false" do
        expect(described_class.valid_variant?(ab_test, "Z")).to be false
      end
    end
  end
end
