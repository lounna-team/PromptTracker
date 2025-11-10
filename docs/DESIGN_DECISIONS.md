# PromptTracker Design Decisions

This document explains the key design decisions and their rationale.

## Table of Contents
1. [When to Sync Prompts to Database](#1-when-to-sync-prompts-to-database)
2. [File-Based vs Database-First](#2-file-based-vs-database-first)
3. [Development vs Production Behavior](#3-development-vs-production-behavior)
4. [Immutable Versions](#4-immutable-versions)
5. [Tracking All Calls (Including Failures)](#5-tracking-all-calls-including-failures)

---

## 1. When to Sync Prompts to Database

### ❓ The Question
Should prompts be synced to the database:
- **Option A:** Lazily (when first used in an LLM call)
- **Option B:** Eagerly (at deployment time)

### ✅ Our Decision: Eager Loading (At Deployment)

### Why This Is Better

#### Predictability
```bash
# With eager loading (our choice)
Deploy → Sync → App starts
# All prompts are in DB before first request
# You know exactly what's available

# With lazy loading (rejected)
Deploy → App starts → First request → Sync
# Prompts appear gradually
# Uncertainty about what's available
```

#### Fail Fast
```bash
# Eager loading
rails prompt_tracker:sync
# Error: greeting.yml has invalid YAML
# Deployment fails ← Good! Fix before production

# Lazy loading
# Deployment succeeds
# First user request fails ← Bad! Users see errors
```

#### Performance
```ruby
# Eager loading
# First request: Fast (prompt already in DB)
LlmCallService.track("greeting", ...) # ~5ms to find prompt

# Lazy loading
# First request: Slow (must create DB records)
LlmCallService.track("greeting", ...) # ~50ms (includes DB write)
```

#### Consistency
```bash
# Eager loading
# All app servers have same prompts immediately
Server 1: Has greeting v2
Server 2: Has greeting v2
Server 3: Has greeting v2

# Lazy loading
# Race conditions possible
Server 1: Creates greeting v1 (first request)
Server 2: Creates greeting v1 (simultaneous request)
# Potential duplicate key errors
```

### Implementation

```bash
# In deployment script (Capistrano, Kubernetes, etc.)
bundle exec rails db:migrate
bundle exec rails prompt_tracker:sync  # ← Sync happens here

# Then restart app servers
# Prompts are already in database
```

---

## 2. File-Based vs Database-First

### ❓ The Question
Where should prompts be authored?
- **Option A:** Directly in database (via web UI)
- **Option B:** In YAML files (synced to database)
- **Option C:** Hybrid (files for production, UI for experiments)

### ✅ Our Decision: Hybrid (Files Primary, UI Secondary)

### Comparison

| Aspect | File-Based | Database-First |
|--------|-----------|----------------|
| Version Control | ✅ Git tracks everything | ❌ No Git history |
| Code Review | ✅ PR process | ❌ No review |
| Rollback | ✅ Git revert | ❌ Manual |
| Testing | ✅ Test locally | ❌ Test in production |
| Audit Trail | ✅ Git blame | ❌ Limited |
| Non-technical Users | ❌ Need Git knowledge | ✅ Easy web UI |
| Deployment | ❌ Requires deploy | ✅ Instant |

### Our Hybrid Approach

```
Production Prompts (File-Based)
├─ Stored in app/prompts/*.yml
├─ Version controlled in Git
├─ Code reviewed via PRs
├─ Deployed via sync task
└─ Status: source='file', can be activated

Experimental Prompts (Web UI)
├─ Created in web interface
├─ Used for testing/iteration
├─ Cannot be activated in production
├─ Can be exported to YAML
└─ Status: source='web_ui', draft only
```

### Workflow

```
┌─────────────────────────────────────────────────┐
│ Development: Fast Iteration                     │
├─────────────────────────────────────────────────┤
│ 1. Create draft in web UI                      │
│ 2. Test with real data                          │
│ 3. Compare with current version                 │
│ 4. Export to YAML                               │
│ 5. Commit to Git                                │
│ 6. Deploy                                       │
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│ Production: Safety First                        │
├─────────────────────────────────────────────────┤
│ 1. Only file-sourced versions can be active     │
│ 2. All changes go through Git                   │
│ 3. Code review required                         │
│ 4. Tested before deployment                     │
└─────────────────────────────────────────────────┘
```

### Why This Works

**For Developers:**
- Familiar Git workflow
- Code review ensures quality
- Can test locally
- Safe rollback

**For Product/QA:**
- Can experiment in web UI
- See results immediately
- Export winners to production
- No Git knowledge needed for testing

---

## 3. Development vs Production Behavior

### ❓ The Question
Should all environments behave the same?

### ✅ Our Decision: Environment-Specific Behavior

### Development Environment

**Goal:** Fast iteration and experimentation

**Behavior:**
```ruby
# config/initializers/prompt_tracker.rb
if Rails.env.development?
  PromptTracker.configure do |config|
    config.auto_sync_prompts = true  # Watch for file changes
    config.prompts_path = Rails.root.join('app/prompts')
  end
end
```

**Features:**
- ✅ Auto-sync on YAML file changes
- ✅ Can create prompts via web UI
- ✅ Can activate any version (even web_ui sourced)
- ✅ Relaxed validation
- ✅ No deployment needed

**Example:**
```bash
# Edit YAML file
vim app/prompts/greeting.yml

# Auto-synced to DB (if enabled)
# Or: rails prompt_tracker:sync

# Test immediately
rails console
> LlmCallService.track("greeting", ...)
```

### Production Environment

**Goal:** Safety and accountability

**Behavior:**
```ruby
# config/initializers/prompt_tracker.rb
if Rails.env.production?
  PromptTracker.configure do |config|
    config.auto_sync_prompts = false  # Never auto-sync
    config.prompts_path = Rails.root.join('app/prompts')
  end
end
```

**Features:**
- ✅ Only file-sourced versions can be activated
- ✅ Manual sync via deployment
- ✅ Strict validation
- ✅ Git audit trail required
- ✅ Code review required

**Example:**
```bash
# Edit locally
vim app/prompts/greeting.yml

# Test in development
rails prompt_tracker:sync

# Commit and PR
git add app/prompts/greeting.yml
git commit -m "Improve greeting"
git push

# Code review...

# Deploy
# Deployment script runs: rails prompt_tracker:sync
```

### Staging Environment

**Goal:** Test production-like behavior

**Behavior:**
```ruby
if Rails.env.staging?
  PromptTracker.configure do |config|
    config.auto_sync_prompts = false
    config.prompts_path = Rails.root.join('app/prompts')
    # Can activate web_ui versions for testing
  end
end
```

**Features:**
- ✅ Mix of development and production
- ✅ Can test web UI features
- ✅ Can activate experimental versions
- ✅ Validate before production

### Why Different Environments?

**Development:**
- Speed > Safety
- Iteration > Process
- Convenience > Control

**Production:**
- Safety > Speed
- Process > Iteration
- Control > Convenience

**Staging:**
- Balance of both
- Test the full workflow
- Catch issues before production

---

## 4. Immutable Versions

### ❓ The Question
Should we allow editing prompt versions after they're created?

### ✅ Our Decision: Immutable Versions

### The Rule

```ruby
# Once a PromptVersion has LlmResponses, it CANNOT be changed
version = PromptVersion.find(1)
version.llm_responses.count  # => 1000

version.update(template: "New template")
# => Error: "template cannot be changed after responses exist"
```

### Why Immutable?

#### Historical Accuracy
```ruby
# With immutable versions
response = LlmResponse.find(123)
response.prompt_version.template
# => Exact template that generated this response

# With mutable versions (rejected)
response = LlmResponse.find(123)
response.prompt_version.template
# => Current template (might be different!)
# Can't reproduce the original response
```

#### Reproducibility
```ruby
# Can replay old versions
old_version = PromptVersion.find(1)
old_version.render(name: "John")
# => Exact same output as when it was active
```

#### Comparison
```ruby
# Compare v1 vs v2 performance
v1 = PromptVersion.find(1)
v2 = PromptVersion.find(2)

v1.average_response_time  # => 1200ms
v2.average_response_time  # => 800ms

# If v1 could change, this comparison is meaningless
```

#### Rollback
```ruby
# Can safely reactivate old version
v1 = PromptVersion.find(1)
v1.activate!  # Works because v1 is unchanged
```

### How to Make Changes

```ruby
# Wrong way (rejected)
version.update(template: "New template")

# Right way (our approach)
new_version = prompt.prompt_versions.create!(
  template: "New template",
  # ... other fields
)
new_version.activate!  # Old version marked as deprecated
```

### Benefits

1. **Audit Trail:** Know exactly what changed and when
2. **Debugging:** Reproduce issues from production
3. **Analysis:** Compare versions accurately
4. **Safety:** Can't accidentally break history

---

## 5. Tracking All Calls (Including Failures)

### ❓ The Question
Should we only track successful LLM calls?

### ✅ Our Decision: Track Everything (Success and Failure)

### What We Track

```ruby
# Successful call
LlmResponse.create!(
  status: 'success',
  response_text: "Hello!",
  response_time_ms: 1200,
  tokens_total: 15,
  cost_usd: 0.00045
)

# Failed call (also tracked!)
LlmResponse.create!(
  status: 'error',
  error_message: "API timeout after 30s",
  error_type: "Timeout::Error",
  response_time_ms: 30000
)
```

### Why Track Failures?

#### Debugging
```ruby
# Find all errors for a prompt
prompt.llm_responses.where(status: 'error')

# See what went wrong
response = LlmResponse.find(123)
response.error_message  # => "API rate limit exceeded"
response.rendered_prompt  # => See what was sent
response.variables_used  # => See what variables were used
```

#### Metrics
```ruby
# Error rate by version
v1_error_rate = v1.llm_responses.where(status: 'error').count.to_f / 
                v1.llm_responses.count
# => 0.01 (1% error rate)

v2_error_rate = v2.llm_responses.where(status: 'error').count.to_f / 
                v2.llm_responses.count
# => 0.05 (5% error rate)

# Conclusion: v2 has more errors, investigate!
```

#### Alerting
```ruby
# Detect spikes in errors
recent_errors = LlmResponse
  .where(status: 'error')
  .where('created_at > ?', 1.hour.ago)
  .count

if recent_errors > 100
  alert("High error rate: #{recent_errors} errors in last hour")
end
```

#### Cost Tracking
```ruby
# Even failed calls cost money (tokens used before failure)
failed_response = LlmResponse.find(123)
failed_response.status  # => 'error'
failed_response.tokens_prompt  # => 100 (still charged!)
failed_response.cost_usd  # => 0.003 (partial cost)
```

### Error Types We Track

```ruby
# Timeout
status: 'timeout'
error_message: "Request timed out after 30s"

# API Error
status: 'error'
error_type: "OpenAI::RateLimitError"
error_message: "Rate limit exceeded"

# Validation Error
status: 'error'
error_type: "PromptTracker::PromptNotFoundError"
error_message: "Prompt 'greeting' not found"
```

### Benefits

1. **Visibility:** See all LLM activity, not just successes
2. **Debugging:** Understand what went wrong
3. **Metrics:** Calculate error rates
4. **Alerting:** Detect issues quickly
5. **Cost:** Track spending even on failures

---

## Summary: Design Philosophy

### Core Principles

1. **Prompts Are Code**
   - Version controlled
   - Code reviewed
   - Tested before deployment

2. **Safety First**
   - Immutable versions
   - Fail fast
   - Audit trail

3. **Developer Experience**
   - Fast iteration in development
   - Controlled deployment in production
   - Easy to use API

4. **Complete Visibility**
   - Track everything
   - Measure everything
   - Learn from everything

5. **Flexibility**
   - Works with any LLM provider
   - Configurable per environment
   - Extensible architecture

---

These design decisions create a system that is:
- **Safe** for production use
- **Fast** for development iteration
- **Transparent** for debugging and analysis
- **Scalable** for growing teams and usage

