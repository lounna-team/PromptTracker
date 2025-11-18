# Sidekiq + Redis Setup for PromptTracker

## Overview

PromptTracker uses **Sidekiq** with **Redis** for background job processing. This enables:

- **Parallel execution** of test runs and evaluators
- **Real-time updates** via ActionCable when tests complete
- **Scalable** job processing with multiple workers

---

## Prerequisites

### Install Redis

**macOS (Homebrew):**
```bash
brew install redis
```

**Ubuntu/Debian:**
```bash
sudo apt-get install redis-server
```

**Other platforms:**
See https://redis.io/download

---

## Running the Application

You need **3 terminal windows** to run the full stack:

### Terminal 1: Redis Server

```bash
redis-server
```

You should see:
```
* Ready to accept connections
```

### Terminal 2: Sidekiq Worker

```bash
bundle exec sidekiq -C config/sidekiq.yml -r ./test/dummy/config/environment.rb
```

You should see:
```
Sidekiq 7.x.x starting
Booting Dummy application
```

### Terminal 3: Rails Server

```bash
bin/rails server
```

Navigate to: `http://localhost:3000/prompt_tracker`

---

## How It Works

### Background Jobs

1. **RunEvaluatorsJob** (`queue: :prompt_tracker_evaluators`)
   - Runs after LLM response is received
   - Executes all configured evaluators (LLM judge, automated, etc.)
   - Updates test run status when complete

### Real-time Updates

1. **ActionCable** (via Redis adapter)
   - Client subscribes to `TestRunChannel` for a specific test run
   - Server broadcasts updates when evaluators complete
   - Client automatically reloads page when test finishes

### Parallel Execution

With Sidekiq, multiple test runs can execute in parallel:

- **Concurrency: 5** (configured in `config/sidekiq.yml`)
- Each test run's evaluators execute in a separate Sidekiq worker
- LLM judge calls within a single test still run sequentially (can be parallelized further if needed)

---

## Configuration

### Sidekiq Configuration

**File:** `config/sidekiq.yml`

```yaml
:concurrency: 5  # Number of parallel workers
:queues:
  - default
  - prompt_tracker_evaluators
  - prompt_tracker_tests
```

### Redis URL

Set via environment variable (optional):

```bash
export REDIS_URL="redis://localhost:6379/0"
```

Default: `redis://localhost:6379/0`

---

## Monitoring

### Sidekiq Web UI

Add to `config/routes.rb`:

```ruby
require 'sidekiq/web'
mount Sidekiq::Web => '/sidekiq'
```

Then visit: `http://localhost:3000/sidekiq`

### Redis CLI

Check Redis connection:

```bash
redis-cli ping
# Should return: PONG
```

View queued jobs:

```bash
redis-cli
> KEYS *
> LLEN queue:prompt_tracker_evaluators
```

---

## Troubleshooting

### "Connection refused" errors

**Problem:** Redis is not running

**Solution:**
```bash
redis-server
```

### Jobs not processing

**Problem:** Sidekiq is not running

**Solution:**
```bash
bundle exec sidekiq -C config/sidekiq.yml -r ./test/dummy/config/environment.rb
```

### ActionCable not connecting

**Problem:** Redis adapter not configured or Redis not running

**Check:** `test/dummy/config/cable.yml`
```yaml
development:
  adapter: redis
  url: redis://localhost:6379/1
```

**Solution:** Ensure Redis is running and URL is correct

---

## Production Deployment

### Environment Variables

```bash
REDIS_URL=redis://your-redis-host:6379/0
```

### Process Management

Use a process manager like **systemd**, **Foreman**, or **Docker Compose**:

**Example Procfile:**
```
web: bundle exec puma -C config/puma.rb
worker: bundle exec sidekiq -C config/sidekiq.yml
```

---

## Performance Tips

1. **Increase concurrency** for more parallel jobs:
   ```yaml
   :concurrency: 10  # in config/sidekiq.yml
   ```

2. **Add more Sidekiq workers** (separate processes):
   ```bash
   bundle exec sidekiq -C config/sidekiq.yml -r ./test/dummy/config/environment.rb -q prompt_tracker_evaluators
   bundle exec sidekiq -C config/sidekiq.yml -r ./test/dummy/config/environment.rb -q default
   ```

3. **Monitor Redis memory usage**:
   ```bash
   redis-cli info memory
   ```

---

## Testing

Run specs with Sidekiq inline mode (jobs execute immediately):

```ruby
# spec/rails_helper.rb
RSpec.configure do |config|
  config.around(:each) do |example|
    Sidekiq::Testing.inline! do
      example.run
    end
  end
end
```

---

## Summary

**To run PromptTracker with full async support:**

1. Start Redis: `redis-server`
2. Start Sidekiq: `bundle exec sidekiq`
3. Start Rails: `bin/rails server`
4. Run tests and watch real-time updates! 🚀
