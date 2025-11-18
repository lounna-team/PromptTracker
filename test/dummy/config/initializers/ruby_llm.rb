# frozen_string_literal: true

# Configure RubyLLM with API keys for various providers
RubyLLM.configure do |config|
  # OpenAI (GPT-4, GPT-3.5, etc.)
  config.openai_api_key = ENV["OPENAI_API_KEY"] if ENV["OPENAI_API_KEY"]

  # Anthropic (Claude models)
  config.anthropic_api_key = ENV["ANTHROPIC_API_KEY"] if ENV["ANTHROPIC_API_KEY"]

  # Note: RubyLLM automatically detects providers from model names
  # Other providers can be configured via their respective ENV vars
  # See: https://github.com/crmne/ruby_llm
end
