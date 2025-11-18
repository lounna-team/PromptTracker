# frozen_string_literal: true

# Ensure ActiveJob is loaded before Sidekiq tries to use it
require "active_job"
require "active_job/queue_adapters/sidekiq_adapter"

Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }
end
