# frozen_string_literal: true

module PromptTracker
  # Controller for the interactive prompt playground.
  # Allows users to draft and test prompt templates with live preview.
  # Can be used standalone or in the context of an existing prompt.
  class PlaygroundController < ApplicationController
    before_action :set_prompt, if: -> { params[:prompt_id].present? }
    before_action :set_version, only: [:show]

    # GET /playground (standalone)
    # GET /prompts/:prompt_id/playground (edit existing)
    # Show the playground interface
    def show
      if @prompt
        @version = @prompt.active_version || @prompt.latest_version
        @variables = extract_variables_from_template(@version&.template || "")
      else
        @version = nil
        @variables = []
      end
      @sample_variables = build_sample_variables(@variables)
    end

    # POST /prompts/:prompt_id/playground/preview
    # POST /playground/preview
    # Preview a template with given variables
    def preview
      template = params[:template]
      # Convert ActionController::Parameters to hash
      variables = params[:variables]&.to_unsafe_h || {}

      # Handle empty template
      if template.blank?
        render json: {
          success: false,
          errors: ["Template cannot be empty"]
        }, status: :unprocessable_entity
        return
      end

      # Render template directly without validation
      # (validation is too strict for simple Mustache templates)
      begin
        renderer = TemplateRenderer.new(template)
        rendered = renderer.render(variables)
        is_liquid = renderer.liquid_template?

        render json: {
          success: true,
          rendered: rendered,
          engine: is_liquid ? "liquid" : "mustache",
          variables_detected: extract_variables_from_template(template)
        }
      rescue Liquid::SyntaxError => e
        render json: {
          success: false,
          errors: ["Liquid syntax error: #{e.message}"]
        }, status: :unprocessable_entity
      rescue => e
        Rails.logger.error "Preview error: #{e.class} - #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        render json: {
          success: false,
          errors: ["Rendering error: #{e.message}"]
        }, status: :unprocessable_entity
      end
    end

    # POST /playground/save (standalone - creates new prompt)
    # POST /prompts/:prompt_id/playground/save (creates new version)
    # Save the template as a new draft version or new prompt
    def save
      template = params[:template]
      notes = params[:notes]
      prompt_name = params[:prompt_name]

      if @prompt
        # Editing existing prompt - create new version
        version = @prompt.prompt_versions.build(
          template: template,
          status: "draft",
          source: "web_ui",
          notes: notes
        )

        if version.save
          render json: {
            success: true,
            version_id: version.id,
            version_number: version.version_number,
            redirect_url: prompt_path(@prompt)
          }
        else
          render json: {
            success: false,
            errors: version.errors.full_messages
          }, status: :unprocessable_entity
        end
      else
        # Standalone mode - create new prompt
        if prompt_name.blank?
          render json: {
            success: false,
            errors: ["Prompt name is required"]
          }, status: :unprocessable_entity
          return
        end

        prompt = Prompt.new(
          name: prompt_name,
          description: notes
        )

        version = prompt.prompt_versions.build(
          template: template,
          status: "draft",
          source: "web_ui",
          notes: notes
        )

        if prompt.save
          render json: {
            success: true,
            prompt_id: prompt.id,
            version_id: version.id,
            version_number: version.version_number,
            redirect_url: prompt_path(prompt)
          }
        else
          render json: {
            success: false,
            errors: prompt.errors.full_messages + version.errors.full_messages
          }, status: :unprocessable_entity
        end
      end
    end

    private

    def set_prompt
      @prompt = Prompt.find(params[:prompt_id])
    end

    def set_version
      if params[:version_id]
        @version = @prompt.prompt_versions.find(params[:version_id])
      end
    end

    # Extract variable names from template
    # Supports both {{variable}} and {{ variable }} syntax
    def extract_variables_from_template(template)
      return [] if template.blank?

      variables = []

      # Extract Mustache-style variables: {{variable}}
      variables += template.scan(/\{\{\s*(\w+)\s*\}\}/).flatten

      # Extract Liquid variables with filters: {{ variable | filter }}
      variables += template.scan(/\{\{\s*(\w+)\s*\|/).flatten

      # Extract Liquid object notation: {{ object.property }}
      variables += template.scan(/\{\{\s*(\w+)\./).flatten

      # Extract from conditionals: {% if variable %}
      variables += template.scan(/\{%\s*if\s+(\w+)/).flatten

      # Extract from loops: {% for item in items %}
      variables += template.scan(/\{%\s*for\s+\w+\s+in\s+(\w+)/).flatten

      variables.uniq.sort
    end

    # Build sample variables hash with empty strings
    def build_sample_variables(variable_names)
      variable_names.each_with_object({}) do |name, hash|
        hash[name] = ""
      end
    end
  end
end
