# frozen_string_literal: true

require 'liquid'

module PromptTracker
  # Service for rendering prompt templates with variable substitution.
  # Supports both Liquid templates and legacy Mustache-style {{variable}} syntax.
  #
  # @example Render with Liquid
  #   renderer = TemplateRenderer.new("Hello {{ name | upcase }}!")
  #   renderer.render(name: "john")
  #   # => "Hello JOHN!"
  #
  # @example Render with Mustache fallback
  #   renderer = TemplateRenderer.new("Hello {{name}}!")
  #   renderer.render(name: "John")
  #   # => "Hello John!"
  class TemplateRenderer
    attr_reader :template_string, :errors

    # Initialize a new template renderer
    #
    # @param template_string [String] the template to render
    def initialize(template_string)
      @template_string = template_string
      @errors = []
    end

    # Render the template with the given variables
    #
    # @param variables [Hash] the variables to substitute
    # @param engine [Symbol] the template engine to use (:liquid or :mustache)
    # @return [String] the rendered template
    # @raise [Liquid::SyntaxError] if Liquid template has syntax errors
    def render(variables = {}, engine: :auto)
      # Ensure we have a hash with indifferent access
      variables = if variables.is_a?(Hash)
        variables.with_indifferent_access
      else
        {}
      end

      case engine
      when :liquid
        render_with_liquid(variables)
      when :mustache
        render_with_mustache(variables)
      when :auto
        # Auto-detect: use Liquid if template contains Liquid syntax, otherwise Mustache
        if liquid_template?
          render_with_liquid(variables)
        else
          render_with_mustache(variables)
        end
      else
        raise ArgumentError, "Unknown template engine: #{engine}"
      end
    end

    # Check if the template is valid
    #
    # @return [Boolean] true if template is valid
    def valid?
      @errors = []

      # Try to parse as Liquid
      begin
        Liquid::Template.parse(template_string)
        true
      rescue Liquid::SyntaxError => e
        @errors << "Liquid syntax error: #{e.message}"
        false
      end
    end

    # Check if template contains Liquid-specific syntax
    #
    # @return [Boolean] true if template uses Liquid syntax
    def liquid_template?
      # Check for Liquid-specific patterns:
      # - Filters: {{ variable | filter }}
      # - Tags: {% if %}, {% for %}, etc.
      # - Objects with dot notation: {{ user.name }}
      template_string.match?(/\{\{.*\|.*\}\}/) ||
        template_string.match?(/\{%.*%\}/) ||
        template_string.match?(/\{\{.*\..*\}\}/)
    end

    private

    # Render template using Liquid engine
    #
    # @param variables [Hash] the variables to substitute
    # @return [String] the rendered template
    def render_with_liquid(variables)
      template = Liquid::Template.parse(template_string)
      template.render(stringify_keys(variables))
    rescue Liquid::SyntaxError => e
      raise Liquid::SyntaxError, "Liquid template error: #{e.message}"
    end

    # Render template using simple Mustache-style substitution
    # This is the legacy method for backward compatibility
    #
    # @param variables [Hash] the variables to substitute
    # @return [String] the rendered template
    def render_with_mustache(variables)
      rendered = template_string.dup
      variables.each do |key, value|
        rendered.gsub!("{{#{key}}}", value.to_s)
      end
      rendered
    end

    # Convert hash keys to strings for Liquid compatibility
    #
    # @param hash [Hash] the hash to convert
    # @return [Hash] hash with string keys
    def stringify_keys(hash)
      hash.transform_keys(&:to_s)
    end
  end
end
