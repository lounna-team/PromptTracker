# frozen_string_literal: true

require "rails_helper"

module PromptTracker
  RSpec.describe LlmJudgeSchema do
    describe ".for_criteria" do
      let(:criteria) { [ "clarity", "accuracy", "completeness" ] }
      let(:score_min) { 0 }
      let(:score_max) { 100 }

      subject(:schema_class) do
        described_class.for_criteria(
          criteria: criteria,
          score_min: score_min,
          score_max: score_max
        )
      end

      it "returns a RubyLLM::Schema subclass" do
        expect(schema_class).to be < RubyLLM::Schema
      end

      it "creates a valid schema class" do
        # The schema class should be a Class
        expect(schema_class).to be_a(Class)
        # It should inherit from RubyLLM::Schema
        expect(schema_class.ancestors).to include(RubyLLM::Schema)
      end

      context "with different criteria" do
        let(:criteria) { [ "relevance", "coherence" ] }

        it "creates schema for the specified criteria" do
          expect(schema_class).to be < RubyLLM::Schema
        end
      end

      context "with different score range" do
        let(:score_min) { 1 }
        let(:score_max) { 10 }

        it "creates schema with the specified range" do
          expect(schema_class).to be < RubyLLM::Schema
        end
      end

      context "with single criterion" do
        let(:criteria) { [ "overall" ] }

        it "creates schema for single criterion" do
          expect(schema_class).to be < RubyLLM::Schema
        end
      end
    end
  end
end
