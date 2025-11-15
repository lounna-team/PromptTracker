# frozen_string_literal: true

module PromptTracker
  # Controller for managing evaluator configurations
  class EvaluatorConfigsController < ApplicationController
    before_action :set_prompt, except: [ :config_form ]
    before_action :set_evaluator_config, only: [ :show, :update, :destroy ]

    # GET /evaluator_configs/config_form
    # Returns the configuration form partial for a specific evaluator
    def config_form
      evaluator_key = params[:evaluator_key]

      # Try to render the specific config form for this evaluator
      template_path = "prompt_tracker/evaluators/configs/#{evaluator_key}"

      render partial: template_path
    rescue ActionView::MissingTemplate
      # If no custom form exists, return a message
      render plain: "No custom configuration form available for this evaluator.", status: :not_found
    end

    # GET /prompts/:prompt_id/evaluators
    # List all evaluator configs for a prompt (returns JSON for AJAX)
    def index
      @evaluator_configs = @prompt.evaluator_configs.by_priority
      @available_evaluators = EvaluatorRegistry.all

      respond_to do |format|
        format.html { render partial: "evaluator_configs/list", locals: { prompt: @prompt, evaluator_configs: @evaluator_configs } }
        format.json { render json: { configs: @evaluator_configs, available: @available_evaluators } }
      end
    end

    # GET /prompts/:prompt_id/evaluators/:id
    # Get a single evaluator config (for editing)
    def show
      respond_to do |format|
        format.json { render json: @evaluator_config }
      end
    end

    # POST /prompts/:prompt_id/evaluators
    # Create a new evaluator config
    def create
      # Process config params (convert arrays from form to proper format)
      processed_params = evaluator_config_params
      processed_params[:config] = process_config_params(processed_params[:config]) if processed_params[:config]

      @evaluator_config = @prompt.evaluator_configs.build(processed_params)

      if @evaluator_config.save
        respond_to do |format|
          format.html { redirect_to @prompt, notice: "Evaluator configured successfully." }
          format.json { render json: @evaluator_config, status: :created }
        end
      else
        respond_to do |format|
          format.html { redirect_to @prompt, alert: "Failed to configure evaluator: #{@evaluator_config.errors.full_messages.join(', ')}" }
          format.json { render json: { errors: @evaluator_config.errors.full_messages }, status: :unprocessable_entity }
        end
      end
    end

    # PATCH/PUT /prompts/:prompt_id/evaluators/:id
    # Update an evaluator config
    def update
      # Process config params (convert arrays from form to proper format)
      processed_params = evaluator_config_params
      processed_params[:config] = process_config_params(processed_params[:config]) if processed_params[:config]

      if @evaluator_config.update(processed_params)
        respond_to do |format|
          format.html { redirect_to @prompt, notice: "Evaluator updated successfully." }
          format.json { render json: @evaluator_config }
        end
      else
        respond_to do |format|
          format.html { redirect_to @prompt, alert: "Failed to update evaluator: #{@evaluator_config.errors.full_messages.join(', ')}" }
          format.json { render json: { errors: @evaluator_config.errors.full_messages }, status: :unprocessable_entity }
        end
      end
    end

    # DELETE /prompts/:prompt_id/evaluators/:id
    # Delete an evaluator config
    def destroy
      @evaluator_config.destroy

      respond_to do |format|
        format.html { redirect_to @prompt, notice: "Evaluator removed successfully." }
        format.json { head :no_content }
      end
    end

    private

    def set_prompt
      @prompt = Prompt.find(params[:prompt_id])
    end

    def set_evaluator_config
      @evaluator_config = @prompt.evaluator_configs.find(params[:id])
    end

    def evaluator_config_params
      params.require(:evaluator_config).permit(
        :evaluator_key,
        :enabled,
        :run_mode,
        :priority,
        :weight,
        :depends_on,
        :min_dependency_score,
        config: {}
      )
    end

    # Process config params from form (handle arrays, convert types, etc.)
    def process_config_params(config_hash)
      return {} if config_hash.blank?

      processed = {}

      config_hash.each do |key, value|
        case key
        when "required_keywords", "forbidden_keywords"
          # Convert textarea input (one per line) to array
          processed[key] = value.is_a?(String) ? value.split("\n").map(&:strip).reject(&:blank?) : value
        when "criteria"
          # Criteria comes as array from checkboxes
          processed[key] = value.is_a?(Array) ? value.reject(&:blank?) : []
        when "case_sensitive", "strict"
          # Convert checkbox values to boolean
          processed[key] = value == "true" || value == true
        when "min_length", "max_length", "ideal_min", "ideal_max", "score_min", "score_max"
          # Convert to integer
          processed[key] = value.to_i
        when "schema"
          # Parse JSON schema if provided
          if value.present? && value.is_a?(String)
            begin
              processed[key] = JSON.parse(value)
            rescue JSON::ParserError => e
              Rails.logger.warn("Failed to parse schema JSON: #{e.message}")
              processed[key] = nil
            end
          else
            processed[key] = value
          end
        else
          # Keep as-is
          processed[key] = value
        end
      end

      processed
    end
  end
end
