# frozen_string_literal: true

module PromptTracker
  # Controller for managing prompt tests.
  class PromptTestsController < ApplicationController
    before_action :set_prompt_version
    before_action :set_test, only: [:show, :edit, :update, :destroy, :run]

    # GET /prompts/:prompt_id/versions/:prompt_version_id/tests
    def index
      @tests = @version.prompt_tests.order(created_at: :desc)
    end

    # POST /prompts/:prompt_id/versions/:prompt_version_id/tests/run_all
    def run_all
      enabled_tests = @version.prompt_tests.enabled

      if enabled_tests.empty?
        redirect_to prompt_prompt_version_prompt_tests_path(@prompt, @version),
                    alert: "No enabled tests to run."
        return
      end

      # Run all enabled tests ASYNCHRONOUSLY
      # Each test will:
      # 1. Execute LLM call synchronously
      # 2. Enqueue background job to run evaluators
      # 3. Return immediately with "running" status
      enabled_tests.each do |test|
        runner = PromptTestRunner.new(test, @version, metadata: { triggered_by: "run_all", user: "web_ui" })
        runner.run! do |rendered_prompt|
          if use_real_llm?
            call_real_llm(rendered_prompt, test.model_config)
          else
            generate_mock_llm_response(rendered_prompt, test.model_config)
          end
        end
      end

      # Redirect immediately - tests are running in background
      redirect_to prompt_prompt_version_prompt_tests_path(@prompt, @version),
                  notice: "Started #{enabled_tests.count} tests! They are running in the background..."
    rescue LlmClientService::MissingApiKeyError => e
      redirect_to prompt_prompt_version_prompt_tests_path(@prompt, @version),
                  alert: "API key missing: #{e.message}. Please configure your API keys in .env file."
    rescue LlmClientService::ApiError => e
      redirect_to prompt_prompt_version_prompt_tests_path(@prompt, @version),
                  alert: "LLM API error: #{e.message}"
    end

    # GET /prompts/:prompt_id/versions/:prompt_version_id/tests/:id
    def show
      @recent_runs = @test.recent_runs(10)
    end

    # GET /prompts/:prompt_id/versions/:prompt_version_id/tests/new
    def new
      @test = @version.prompt_tests.build(
        template_variables: {},
        expected_patterns: [],
        model_config: { provider: "openai", model: "gpt-4" },
        evaluator_configs: [],
        tags: []
      )
    end

    # POST /prompts/:prompt_id/versions/:prompt_version_id/tests
    def create
      @test = @version.prompt_tests.build(test_params)

      if @test.save
        redirect_to prompt_prompt_version_prompt_test_path(@prompt, @version, @test), notice: "Test created successfully."
      else
        render :new, status: :unprocessable_entity
      end
    end

    # GET /prompts/:prompt_id/versions/:prompt_version_id/tests/:id/edit
    def edit
    end

    # PATCH/PUT /prompts/:prompt_id/versions/:prompt_version_id/tests/:id
    def update
      if @test.update(test_params)
        redirect_to prompt_prompt_version_prompt_test_path(@prompt, @version, @test), notice: "Test updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /prompts/:prompt_id/versions/:prompt_version_id/tests/:id
    def destroy
      @test.destroy
      redirect_to prompt_prompt_version_prompt_tests_path(@prompt, @version), notice: "Test deleted successfully."
    end

    # POST /prompts/:prompt_id/versions/:prompt_version_id/tests/:id/run
    def run
      # Run test against this specific version
      runner = PromptTestRunner.new(@test, @version, metadata: { triggered_by: "manual", user: "web_ui" })

      # Log the mode for debugging
      Rails.logger.info "🔍 PROMPT_TRACKER_USE_REAL_LLM = #{ENV['PROMPT_TRACKER_USE_REAL_LLM'].inspect}"
      Rails.logger.info "🔍 use_real_llm? = #{use_real_llm?}"

      # Execute the test asynchronously - evaluators run in background
      test_run = runner.run! do |rendered_prompt|
        if use_real_llm?
          Rails.logger.info "🚀 Using REAL LLM API"
          call_real_llm(rendered_prompt, @test.model_config)
        else
          Rails.logger.info "🎭 Using MOCK LLM response"
          generate_mock_llm_response(rendered_prompt, @test.model_config)
        end
      end

      # Redirect to test run page to show progress
      redirect_to prompt_test_run_path(test_run),
                  notice: "Test started! Evaluators are running in the background..."
    rescue LlmClientService::MissingApiKeyError => e
      redirect_to prompt_prompt_version_prompt_test_path(@prompt, @version, @test),
                  alert: "API key missing: #{e.message}. Please configure your API keys in .env file."
    rescue LlmClientService::ApiError => e
      redirect_to prompt_prompt_version_prompt_test_path(@prompt, @version, @test),
                  alert: "LLM API error: #{e.message}"
    end

    private

    def set_prompt_version
      @version = PromptVersion.find(params[:prompt_version_id])
      @prompt = @version.prompt
    end

    def set_test
      @test = @version.prompt_tests.find(params[:id])
    end

    def test_params
      permitted = params.require(:prompt_test).permit(
        :name,
        :description,
        :expected_output,
        :enabled,
        :prompt_test_suite_id,
        :template_variables,
        :expected_patterns,
        :model_config,
        :evaluator_configs,
        :tags,
        :metadata
      )

      # Parse JSON strings to hashes/arrays
      [ :template_variables, :model_config, :metadata ].each do |key|
        if permitted[key].is_a?(String)
          permitted[key] = JSON.parse(permitted[key])
        end
      end

      [ :expected_patterns, :evaluator_configs, :tags ].each do |key|
        if permitted[key].is_a?(String)
          permitted[key] = JSON.parse(permitted[key])
        end
      end

      permitted
    end

    # Check if real LLM API calls should be used
    #
    # @return [Boolean] true if PROMPT_TRACKER_USE_REAL_LLM is set to 'true'
    def use_real_llm?
      ENV["PROMPT_TRACKER_USE_REAL_LLM"] == "true"
    end

    # Call real LLM API
    #
    # @param rendered_prompt [String] the rendered prompt
    # @param model_config [Hash] the model configuration
    # @return [Hash] LLM API response
    def call_real_llm(rendered_prompt, model_config)
      config = model_config.with_indifferent_access
      provider = config[:provider] || "openai"
      model = config[:model] || "gpt-4"
      temperature = config[:temperature] || 0.7
      max_tokens = config[:max_tokens]

      LlmClientService.call(
        provider: provider,
        model: model,
        prompt: rendered_prompt,
        temperature: temperature,
        max_tokens: max_tokens
      )[:raw] # Return raw response in provider format
    end

    # Generate a mock LLM response for testing
    #
    # @param rendered_prompt [String] the rendered prompt
    # @param model_config [Hash] the model configuration
    # @return [Hash] mock LLM response in OpenAI format
    def generate_mock_llm_response(rendered_prompt, model_config)
      provider = model_config["provider"] || model_config[:provider] || "openai"

      # Generate a realistic mock response based on the prompt
      mock_text = "This is a mock response to: #{rendered_prompt.truncate(100)}\n\n"
      mock_text += "In a production environment, this would be replaced with an actual API call to #{provider}.\n"
      mock_text += "The response would be generated by the configured model and would address the prompt appropriately."

      # Return in OpenAI-like format for compatibility
      {
        "choices" => [
          {
            "message" => {
              "content" => mock_text
            }
          }
        ]
      }
    end
  end
end
