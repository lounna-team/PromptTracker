# frozen_string_literal: true

require "ruby_llm/schema"

module PromptTracker
  # Factory for creating RubyLLM::Schema classes for LLM judge evaluations.
  #
  # This replaces the manual JSON Schema building with RubyLLM's elegant DSL.
  #
  # @example Create a schema for evaluation
  #   schema = LlmJudgeSchema.for_criteria(
  #     criteria: ["clarity", "accuracy", "completeness"],
  #     score_min: 0,
  #     score_max: 100
  #   )
  #
  #   chat = RubyLLM.chat(model: "gpt-4o").with_schema(schema)
  #   response = chat.ask("Evaluate this response...")
  #   response.content[:overall_score]  # => 85.0
  #   response.content[:criteria_scores][:clarity]  # => 90.0
  #
  class LlmJudgeSchema
    # Create a RubyLLM::Schema class for LLM judge evaluation
    #
    # @param criteria [Array<String>] list of evaluation criteria
    # @param score_min [Integer] minimum score value
    # @param score_max [Integer] maximum score value
    # @return [Class] a RubyLLM::Schema subclass
    def self.for_criteria(criteria:, score_min:, score_max:)
      # Capture variables for use in the class definition
      criteria_list = criteria
      min_score = score_min
      max_score = score_max

      Class.new(RubyLLM::Schema) do
        # Overall score
        number :overall_score,
               description: "Overall score from #{min_score} to #{max_score}"

        # Criteria scores as a nested object
        object :criteria_scores do
          criteria_list.each do |criterion|
            number criterion.to_sym,
                   description: "Score for #{criterion} (#{min_score}-#{max_score})"
          end
        end

        # Feedback text
        string :feedback,
               description: "Detailed feedback explaining the scores and evaluation"
      end
    end
  end
end
