# frozen_string_literal: true

module PromptTracker
  module Evaluators
    # Uses an LLM to evaluate another LLM's response.
    #
    # This evaluator sends the original prompt and response to a "judge" LLM
    # and asks it to score the response based on specified criteria.
    #
    # @example Evaluate with default criteria
    #   evaluator = LlmJudgeEvaluator.new(llm_response, {
    #     judge_model: "gpt-4",
    #     criteria: ["accuracy", "helpfulness", "tone"]
    #   })
    #   evaluation = evaluator.evaluate do |judge_prompt|
    #     # Call your LLM API here
    #     OpenAI.chat(model: "gpt-4", messages: [{ role: "user", content: judge_prompt }])
    #   end
    #
    # @example Custom evaluation prompt
    #   evaluator = LlmJudgeEvaluator.new(llm_response, {
    #     judge_model: "claude-3-opus",
    #     criteria: ["technical_accuracy"],
    #     custom_instructions: "Focus on technical correctness for a senior developer audience"
    #   })
    #
    class LlmJudgeEvaluator
      attr_reader :llm_response, :config

      # Default configuration
      DEFAULT_CONFIG = {
        judge_model: "gpt-4",
        criteria: %w[accuracy helpfulness tone],
        score_min: 0,
        score_max: 5,
        custom_instructions: nil
      }.freeze

      # Default evaluation criteria descriptions
      CRITERIA_DESCRIPTIONS = {
        "accuracy" => "Is the response factually correct and accurate?",
        "helpfulness" => "Is the response helpful and addresses the user's needs?",
        "tone" => "Is the tone appropriate and professional?",
        "clarity" => "Is the response clear and easy to understand?",
        "completeness" => "Does the response fully address the question?",
        "conciseness" => "Is the response concise without unnecessary information?"
      }.freeze

      def initialize(llm_response, config = {})
        @llm_response = llm_response
        @config = DEFAULT_CONFIG.merge(config)
      end

      # Evaluate the response using an LLM judge
      #
      # @yield [judge_prompt] Yields the evaluation prompt to send to the judge LLM
      # @yieldparam judge_prompt [String] the prompt to send to the judge
      # @yieldreturn [String, Hash] the judge's response (text or structured response)
      # @return [Evaluation] the created evaluation
      #
      # @example
      #   evaluation = evaluator.evaluate do |judge_prompt|
      #     OpenAI.chat(
      #       model: "gpt-4",
      #       messages: [{ role: "user", content: judge_prompt }]
      #     )
      #   end
      def evaluate(&block)
        raise ArgumentError, "Block required to call judge LLM" unless block_given?

        # Generate the evaluation prompt
        judge_prompt = build_judge_prompt

        # Call the judge LLM
        judge_response = yield(judge_prompt)

        # Parse the judge's response
        parsed = parse_judge_response(judge_response)

        # Create the evaluation
        EvaluationService.create_llm_judge(
          llm_response: llm_response,
          judge_model: config[:judge_model],
          score: parsed[:overall_score],
          score_min: config[:score_min],
          score_max: config[:score_max],
          criteria_scores: parsed[:criteria_scores],
          feedback: parsed[:feedback],
          metadata: {
            judge_model: config[:judge_model],
            criteria: config[:criteria],
            judge_prompt: judge_prompt,
            raw_judge_response: judge_response.to_s
          }
        )
      end

      private

      # Build the prompt to send to the judge LLM
      #
      # @return [String] the evaluation prompt
      def build_judge_prompt
        criteria_list = config[:criteria].map do |criterion|
          description = CRITERIA_DESCRIPTIONS[criterion] || "Evaluate #{criterion}"
          "- #{criterion.capitalize}: #{description}"
        end.join("\n")

        custom_section = if config[:custom_instructions]
                           "\n\nAdditional Instructions:\n#{config[:custom_instructions]}"
                         else
                           ""
                         end

        <<~PROMPT
          You are an expert evaluator of AI-generated responses. Please evaluate the following LLM response.

          ORIGINAL PROMPT:
          #{llm_response.rendered_prompt}

          LLM RESPONSE TO EVALUATE:
          #{llm_response.response_text}

          EVALUATION CRITERIA:
          #{criteria_list}
          #{custom_section}

          Please provide your evaluation in the following format:

          OVERALL SCORE: [score from #{config[:score_min]} to #{config[:score_max]}]

          CRITERIA SCORES:
          #{config[:criteria].map { |c| "#{c}: [score from #{config[:score_min]} to #{config[:score_max]}]" }.join("\n")}

          FEEDBACK:
          [Your detailed feedback explaining the scores]
        PROMPT
      end

      # Parse the judge LLM's response
      #
      # @param response [String, Hash] the judge's response
      # @return [Hash] parsed scores and feedback
      def parse_judge_response(response)
        text = extract_text(response)

        {
          overall_score: extract_overall_score(text),
          criteria_scores: extract_criteria_scores(text),
          feedback: extract_feedback(text)
        }
      end

      # Extract text from various response formats
      #
      # @param response [String, Hash] the response
      # @return [String] extracted text
      def extract_text(response)
        return response if response.is_a?(String)

        # Try common LLM response formats
        response.dig("choices", 0, "message", "content") ||
          response.dig("content", 0, "text") ||
          response["text"] ||
          response.to_s
      end

      # Extract overall score from judge response
      #
      # @param text [String] the judge's response text
      # @return [Float] the overall score
      def extract_overall_score(text)
        # Look for "OVERALL SCORE: X" or "Overall: X"
        match = text.match(/OVERALL\s+SCORE:\s*([\d.]+)/i) ||
                text.match(/Overall:\s*([\d.]+)/i)

        if match
          match[1].to_f
        else
          # Fallback: average of criteria scores
          criteria_scores = extract_criteria_scores(text)
          criteria_scores.values.sum / criteria_scores.length.to_f
        end
      end

      # Extract criteria scores from judge response
      #
      # @param text [String] the judge's response text
      # @return [Hash] hash of criterion to score
      def extract_criteria_scores(text)
        scores = {}

        config[:criteria].each do |criterion|
          # Look for "criterion: X" or "criterion - X"
          pattern = /#{Regexp.escape(criterion)}[:\-\s]+([\d.]+)/i
          match = text.match(pattern)

          scores[criterion] = match ? match[1].to_f : config[:score_max] / 2.0
        end

        scores
      end

      # Extract feedback from judge response
      #
      # @param text [String] the judge's response text
      # @return [String] the feedback text
      def extract_feedback(text)
        # Look for "FEEDBACK:" section
        match = text.match(/FEEDBACK:\s*(.+)/im)

        if match
          match[1].strip
        else
          # Fallback: use the entire response
          text.strip
        end
      end
    end
  end
end

