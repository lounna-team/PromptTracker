# PromptTracker Implementation Plan

## Table of Contents
1. [Overview & Philosophy](#overview--philosophy)
2. [Phase 1: Database Schema & Models](#phase-1-database-schema--models)
3. [Phase 2: File-Based Prompt System](#phase-2-file-based-prompt-system)
4. [Phase 3: Core Tracking Service](#phase-3-core-tracking-service)
5. [Design Decisions](#design-decisions)
6. [Development vs Production Behavior](#development-vs-production-behavior)

---

## Overview & Philosophy

### Core Concept
PromptTracker treats **prompts as code**. Just like you version control your Ruby code, you should version control your prompts. This means:

- Prompts live in **YAML files** in your repository
- Changes go through **Git commits and PRs**
- Code review ensures **quality and safety**
- The database is a **runtime cache** of your prompts, not the source of truth

### The Flow
```
Developer writes YAML → Git commit → Deploy → Sync to DB → Track LLM calls → Analyze performance
```

---

## Phase 1: Database Schema & Models

### Purpose
Create the foundational data structures to store prompts, their versions, LLM responses, and evaluations.

### The Four Core Tables

#### 1. **Prompts Table** (`prompt_tracker_prompts`)
**What it stores:** The high-level prompt definition - think of it as a "prompt family"

**Why it exists:**
- Groups all versions of the same prompt together
- Provides metadata (name, description, category)
- Allows you to find a prompt by name (e.g., "customer_support_greeting")

**Real-world analogy:** Like a GitHub repository - it's the container for all versions

**Key fields:**
- `name`: Unique identifier (e.g., "customer_support_greeting")
- `description`: Human-readable explanation
- `category`: For organization (e.g., "support", "sales")
- `tags`: Flexible categorization (JSON array)
- `archived_at`: Soft delete (keep history but hide from active use)

**Example:**
```ruby
Prompt.create!(
  name: "customer_support_greeting",
  description: "Initial greeting for customer support chats",
  category: "support",
  tags: ["customer_facing", "greeting"]
)
```

---

#### 2. **PromptVersions Table** (`prompt_tracker_prompt_versions`)
**What it stores:** Each specific version of a prompt template

**Why it exists:**
- Prompts evolve over time - you need to track each iteration
- Different versions can be A/B tested
- You need to know which version generated which response
- Immutability: once a version has responses, it can't be changed

**Real-world analogy:** Like Git commits - each version is a snapshot in time

**Key fields:**
- `prompt_id`: Links to parent Prompt
- `version_number`: Auto-incremented (1, 2, 3...)
- `template`: The actual prompt text with `{{variables}}`
- `variables_schema`: Defines what variables are expected (JSON)
- `model_config`: LLM settings (temperature, max_tokens, etc.)
- `status`: draft/active/deprecated/archived
- `source`: file/web_ui/api (where it came from)
- `activated_at`: When this version went live

**Example:**
```ruby
PromptVersion.create!(
  prompt: prompt,
  version_number: 1,
  template: "Hello {{customer_name}}! How can I help with your {{issue}}?",
  variables_schema: {
    customer_name: { type: "string", required: true },
    issue: { type: "string", required: false }
  },
  model_config: { temperature: 0.7, max_tokens: 150 },
  status: "active",
  source: "file"
)
```

**Why version_number matters:**
- You can compare v1 vs v2 performance
- You can roll back to a previous version
- You can run A/B tests (50% get v1, 50% get v2)

---

#### 3. **LlmResponses Table** (`prompt_tracker_llm_responses`)
**What it stores:** Every single LLM API call made using a prompt version

**Why it exists:**
- Track what was actually sent to the LLM
- Measure performance (response time, token usage)
- Calculate costs
- Debug issues
- Analyze quality over time

**Real-world analogy:** Like server access logs - every request is recorded

**Key fields:**

**Identity:**
- `prompt_version_id`: Which version was used
- `request_id`: Unique ID for this specific call (UUID)

**What was sent:**
- `rendered_prompt`: The final prompt after variable substitution
- `variables_used`: The actual variable values (JSON)

**LLM details:**
- `provider`: "openai", "anthropic", "google"
- `model`: "gpt-4", "claude-3-sonnet"

**What came back:**
- `response_text`: The LLM's actual response
- `response_metadata`: Full API response (JSON)

**Performance metrics:**
- `response_time_ms`: How long it took (milliseconds)
- `tokens_prompt`: Input tokens used
- `tokens_completion`: Output tokens used
- `tokens_total`: Total tokens
- `cost_usd`: Calculated cost in dollars

**Status tracking:**
- `status`: pending/success/error/timeout
- `error_message`: If it failed, why?

**Context:**
- `environment`: production/staging/development
- `user_id`: Which end-user triggered this
- `session_id`: Group related calls together
- `metadata`: Any custom data you want to track

**Example:**
```ruby
LlmResponse.create!(
  prompt_version: version,
  provider: "openai",
  model: "gpt-4",
  rendered_prompt: "Hello John! How can I help with your billing issue?",
  variables_used: { customer_name: "John", issue: "billing" },
  response_text: "I'd be happy to help you with your billing question...",
  response_time_ms: 1250,
  tokens_prompt: 25,
  tokens_completion: 50,
  tokens_total: 75,
  cost_usd: 0.00225,
  status: "success",
  environment: "production",
  user_id: "user_123",
  session_id: "session_456"
)
```

**Why this is valuable:**
- "Version 2 is 30% faster than version 1"
- "This prompt costs $0.002 per call on average"
- "User X had an error at 2pm - let's see what prompt was used"

---

#### 4. **Evaluations Table** (`prompt_tracker_evaluations`)
**What it stores:** Quality ratings/scores for LLM responses

**Why it exists:**
- Not all LLM responses are good - you need to measure quality
- Compare which prompt version produces better results
- Detect regressions (new version performing worse)
- Train better prompts based on feedback

**Real-world analogy:** Like product reviews - rating the quality of each response

**Key fields:**

**What's being evaluated:**
- `llm_response_id`: Which response is being rated

**Who's evaluating:**
- `evaluator_type`: human/automated/llm_judge
- `evaluator_id`: User ID or system name

**The evaluation:**
- `score`: Overall score (0-100)
- `criteria_scores`: Breakdown by criteria (JSON)
  - Example: `{ accuracy: 95, relevance: 80, tone: 90 }`
- `passed`: Binary pass/fail
- `feedback`: Text explanation
- `tags`: Categorization (e.g., ["hallucination", "off-topic"])

**For automated evaluations:**
- `evaluation_prompt_version_id`: If using LLM-as-judge, which prompt evaluated this?
- `evaluation_config`: Settings used for evaluation

**Example:**
```ruby
# Human evaluation
Evaluation.create!(
  llm_response: response,
  evaluator_type: "human",
  evaluator_id: "admin_user_5",
  score: 85,
  criteria_scores: {
    accuracy: 90,
    helpfulness: 85,
    tone: 80
  },
  passed: true,
  feedback: "Good response but could be more concise"
)

# Automated evaluation (LLM-as-judge)
Evaluation.create!(
  llm_response: response,
  evaluator_type: "llm_judge",
  evaluator_id: "gpt-4-judge",
  score: 92,
  criteria_scores: {
    factual_accuracy: 95,
    relevance: 90,
    safety: 90
  },
  passed: true,
  evaluation_prompt_version: judge_prompt_version
)
```

**Why this matters:**
- "Version 3 has 95% pass rate vs version 2's 80%"
- "Responses to angry customers score lower - need to improve that prompt"
- "Automated judge agrees with human ratings 85% of the time"

---

### Model Relationships

```
Prompt (1) ──< (many) PromptVersion
                         │
                         │ (1)
                         │
                         ▼
                      (many) LlmResponse
                         │
                         │ (1)
                         │
                         ▼
                      (many) Evaluation
```

**In plain English:**
1. One Prompt has many PromptVersions
2. One PromptVersion has many LlmResponses
3. One LlmResponse has many Evaluations

**Why this structure:**
- You can see all versions of a prompt
- You can see all responses generated by a specific version
- You can see all evaluations for a specific response
- You can aggregate: "What's the average score for all responses from version 3?"

---

## Phase 2: File-Based Prompt System

### The Problem We're Solving
**Question:** Where should prompts be stored?

**Bad answer:** Only in the database
- ❌ No version control
- ❌ No code review
- ❌ Hard to track changes
- ❌ Risky to edit in production

**Good answer:** In YAML files, synced to database
- ✅ Git tracks every change
- ✅ Code review before deployment
- ✅ Can test locally
- ✅ Can roll back easily

### The Components

#### 1. **YAML Prompt Files**
**What they are:** Human-readable files that define prompts

**Where they live:** `app/prompts/` in your Rails app

**Example structure:**
```
app/prompts/
  customer_support/
    greeting.yml
    escalation.yml
    closing.yml
  sales/
    qualification.yml
    demo_booking.yml
  evaluations/
    quality_judge.yml
```

**Example file content:**
```yaml
# app/prompts/customer_support/greeting.yml
name: customer_support_greeting
description: Initial greeting for customer support interactions
category: support
tags:
  - customer_facing
  - greeting

variables_schema:
  customer_name:
    type: string
    required: true
    description: The customer's first name
  issue_category:
    type: string
    required: false
    description: Type of issue (billing, technical, etc.)

model_config:
  temperature: 0.7
  max_tokens: 150
  top_p: 0.9

template: |
  You are a friendly customer support agent for our company.

  Greet {{customer_name}} warmly and acknowledge their {{issue_category}} issue.

  Be empathetic, professional, and set a positive tone for the conversation.
```

**Why YAML:**
- Easy to read and write
- Supports multi-line text (perfect for prompts)
- Can be validated
- Standard format

---

#### 2. **FileSyncService** - The Bridge Between Files and Database

**What it does:** Reads YAML files and creates/updates database records

**When it runs:**
- **Production:** After deployment (via rake task)
- **Development:** Automatically when files change (optional)
- **Manual:** `rails prompt_tracker:sync`

**How it works (step by step):**

1. **Scan for YAML files**
   - Looks in `app/prompts/**/*.yml`
   - Finds all prompt definition files

2. **Read each file**
   - Parse YAML content
   - Validate required fields (name, template)

3. **Find or create Prompt record**
   - Look up by `name` field
   - If doesn't exist, create new Prompt
   - Update description, category, tags

4. **Check if version needs updating**
   - Compare template with latest file-sourced version
   - If template changed → create new version
   - If unchanged → skip (no duplicate versions)

5. **Create new PromptVersion**
   - Auto-increment version_number
   - Set source='file'
   - Set status='active'
   - Add note about which file it came from

**Example scenario:**

```ruby
# First sync - greeting.yml exists
FileSyncService.sync_all!
# Creates: Prompt(name: "customer_support_greeting")
# Creates: PromptVersion(version: 1, template: "Hello {{name}}...")

# You edit greeting.yml, change template
FileSyncService.sync_all!
# Finds: Prompt(name: "customer_support_greeting") - already exists
# Compares: template changed!
# Creates: PromptVersion(version: 2, template: "Hi {{name}}...")
# Updates: version 1 status to 'deprecated'

# You sync again without changes
FileSyncService.sync_all!
# Finds: Prompt exists
# Compares: template unchanged
# Does: Nothing (no duplicate version created)
```

**Why this is smart:**
- Only creates versions when content actually changes
- Preserves history (old versions stay in DB)
- Idempotent (safe to run multiple times)
- Fast (only processes changed files)

---

#### 3. **Configuration System**

**What it does:** Lets you configure how PromptTracker behaves

**Where it lives:** `config/initializers/prompt_tracker.rb`

**Example:**
```ruby
PromptTracker.configure do |config|
  # Where to find prompt YAML files
  config.prompts_path = Rails.root.join('app/prompts')

  # Auto-sync in development (watches for file changes)
  config.auto_sync_prompts = Rails.env.development?

  # Default environment tag for tracking
  config.default_environment = Rails.env.to_s
end
```

**Why configurable:**
- Different apps have different needs
- Development vs production behave differently
- Easy to customize without changing gem code

---

#### 4. **Rake Tasks**

**What they do:** Command-line tools for managing prompts

**Available tasks:**

```bash
# Sync all YAML files to database
rails prompt_tracker:sync

# List all prompts and versions
rails prompt_tracker:list

# Show statistics
rails prompt_tracker:stats
```

**When you use them:**
- After deployment (in production)
- After pulling changes (in development)
- When debugging ("what prompts are in the DB?")

---

### The Workflow in Practice

#### Development Environment
```bash
# 1. Developer creates new prompt
touch app/prompts/sales/qualification.yml
# Edit file in VSCode

# 2. Auto-sync (if enabled) or manual sync
rails prompt_tracker:sync

# 3. Test in Rails console
result = PromptTracker::LlmCallService.track(
  prompt_name: "sales_qualification",
  variables: { prospect_name: "Alice" },
  provider: "openai",
  model: "gpt-4"
) { |prompt| "Mock response" }

# 4. Commit to Git
git add app/prompts/sales/qualification.yml
git commit -m "Add sales qualification prompt"
```

#### Production Environment
```bash
# 1. Deploy code (includes new YAML files)
git push production main

# 2. Run migrations and sync (in deploy script)
rails db:migrate
rails prompt_tracker:sync

# 3. Prompts are now available in production
# LLM calls will use the new prompts
```

---

## Phase 3: Core Tracking Service

### The Problem We're Solving
**Question:** How do we actually track LLM calls?

**Requirements:**
- Capture what was sent to the LLM
- Measure performance (time, tokens, cost)
- Handle errors gracefully
- Make it easy for developers to use

### The Components

#### 1. **LlmCallService** - The Main Tracking Engine

**What it does:** Wraps your LLM API calls and automatically tracks everything

**How developers use it:**

```ruby
result = PromptTracker::LlmCallService.track(
  prompt_name: "customer_support_greeting",
  variables: { customer_name: "John", issue_category: "billing" },
  provider: "openai",
  model: "gpt-4",
  user_id: current_user.id
) do |rendered_prompt|
  # Your actual LLM API call goes here
  OpenAI::Client.new.chat(
    messages: [{ role: "user", content: rendered_prompt }],
    model: "gpt-4"
  )
end

# result contains:
# - llm_response: The database record
# - response_text: The actual LLM response
# - tracking_id: For later reference
```

**What happens under the hood (step by step):**

1. **Find the prompt**
   - Look up Prompt by name
   - Raise error if not found

2. **Find the version**
   - If version number specified → use that version
   - Otherwise → use active version
   - Raise error if not found

3. **Render the template**
   - Take template: `"Hello {{customer_name}}!"`
   - Substitute variables: `"Hello John!"`
   - Result: rendered_prompt

4. **Create LlmResponse record (status: pending)**
   - Store rendered_prompt
   - Store variables_used
   - Store provider, model
   - Store user context
   - Generate request_id (UUID)

5. **Execute the LLM call**
   - Start timer
   - Call the block you provided (your API call)
   - Stop timer
   - Calculate response_time_ms

6. **Extract response data**
   - Get response text
   - Get token counts (if available)
   - Get metadata

7. **Update LlmResponse record (status: success)**
   - Store response_text
   - Store response_time_ms
   - Store tokens
   - Calculate cost

8. **Return result**
   - Give you the response text
   - Give you the tracking record

**Error handling:**
```ruby
# If LLM call fails
begin
  result = PromptTracker::LlmCallService.track(...) do |prompt|
    raise "API timeout"
  end
rescue => e
  # LlmResponse record is marked as error
  # error_message: "API timeout"
  # status: "error"
end
```

**Why this design:**
- ✅ Non-invasive (you still control the LLM call)
- ✅ Automatic tracking (no manual record creation)
- ✅ Flexible (works with any LLM provider)
- ✅ Error-safe (failures are tracked too)

---

#### 2. **CostCalculator** - Automatic Cost Tracking

**What it does:** Calculates how much each LLM call costs

**How it works:**

```ruby
calculator = CostCalculator.new("openai", "gpt-4")
cost = calculator.calculate(
  tokens_prompt: 100,      # Input tokens
  tokens_completion: 50    # Output tokens
)
# => 0.006 (in USD)
```

**Pricing database:**
```ruby
PRICING = {
  'openai' => {
    'gpt-4' => { input: 0.03, output: 0.06 },  # per 1K tokens
    'gpt-3.5-turbo' => { input: 0.0015, output: 0.002 }
  },
  'anthropic' => {
    'claude-3-opus' => { input: 0.015, output: 0.075 },
    'claude-3-sonnet' => { input: 0.003, output: 0.015 }
  }
}
```

**Calculation:**
```
Input cost = (100 tokens / 1000) * $0.03 = $0.003
Output cost = (50 tokens / 1000) * $0.06 = $0.003
Total = $0.006
```

**Why this matters:**
- Track spending per prompt
- Compare cost of different models
- Budget forecasting
- Detect expensive prompts

**Example insights:**
- "Version 2 uses 30% fewer tokens → saves $500/month"
- "GPT-4 costs 10x more than GPT-3.5 for this prompt"
- "This prompt costs $0.002 per call × 10,000 calls/day = $20/day"

---

#### 3. **Trackable Module** - Convenience Helper

**What it does:** Makes tracking easier in your controllers/services

**How to use:**

```ruby
class CustomerSupportController < ApplicationController
  include PromptTracker::Trackable

  def generate_greeting
    result = track_llm_call(
      "customer_support_greeting",
      variables: { customer_name: params[:name] },
      provider: "openai",
      model: "gpt-4",
      user_id: current_user.id
    ) do |prompt|
      OpenAI::Client.new.chat(messages: [{ role: "user", content: prompt }])
    end

    render json: { greeting: result.response_text }
  end
end
```

**Why it's helpful:**
- Shorter syntax
- Consistent usage across your app
- Easy to remember

---

## Design Decisions

### Decision 1: When Are Prompts Synced to Database?

**The Question:** Should prompts be saved to the database:
- A) When first used (lazy loading)
- B) At deployment time (eager loading)

**Our Choice: B) At deployment time (eager loading)**

**Why:**

✅ **Predictability**
- You know exactly what prompts exist before any LLM calls
- No surprises in production

✅ **Fail fast**
- If YAML is invalid, deployment fails
- Better than discovering errors during an LLM call

✅ **Performance**
- No database writes during LLM calls
- Faster response times

✅ **Consistency**
- All servers have same prompts immediately
- No race conditions

✅ **Debugging**
- Can inspect prompts in database before using them
- Can test in Rails console immediately after deploy

**How it works:**

```bash
# In your deployment script (e.g., Capistrano, Kubernetes)
bundle exec rails db:migrate
bundle exec rails prompt_tracker:sync  # ← This syncs prompts

# Now app servers restart with prompts already in DB
```

**Alternative (lazy loading) problems:**
- ❌ First request after deploy might be slow (DB write)
- ❌ Invalid YAML discovered in production
- ❌ Race condition if multiple servers try to create same prompt
- ❌ Hard to debug ("why isn't my prompt available?")

---

### Decision 2: Development vs Production Behavior

**The Question:** Should development and production work differently?

**Our Choice: Yes, with smart defaults**

#### Development Environment

**Behavior:**
- ✅ Auto-sync on file changes (optional, configurable)
- ✅ Can create prompts via web UI
- ✅ Can activate any version (even web_ui sourced)
- ✅ Relaxed validation

**Why:**
- Fast iteration
- Easy experimentation
- No deployment needed to test changes

**Configuration:**
```ruby
# config/initializers/prompt_tracker.rb
if Rails.env.development?
  PromptTracker.configure do |config|
    config.auto_sync_prompts = true  # Watch for file changes
    config.prompts_path = Rails.root.join('app/prompts')
  end
end
```

**Workflow:**
```bash
# 1. Edit YAML file
vim app/prompts/greeting.yml

# 2. Auto-synced to DB (if enabled)
# Or manually: rails prompt_tracker:sync

# 3. Test immediately
rails console
> result = PromptTracker::LlmCallService.track(...)
```

---

#### Production Environment

**Behavior:**
- ✅ Only file-sourced versions can be activated
- ✅ Manual sync via rake task (in deploy script)
- ✅ Strict validation
- ✅ Audit trail (all changes via Git)

**Why:**
- Safety (no accidental changes)
- Accountability (Git history)
- Reliability (tested before deployment)

**Configuration:**
```ruby
# config/initializers/prompt_tracker.rb
if Rails.env.production?
  PromptTracker.configure do |config|
    config.auto_sync_prompts = false  # Never auto-sync in production
    config.prompts_path = Rails.root.join('app/prompts')
  end
end
```

**Workflow:**
```bash
# 1. Edit YAML file locally
vim app/prompts/greeting.yml

# 2. Test in development
rails prompt_tracker:sync
# Test...

# 3. Commit and PR
git add app/prompts/greeting.yml
git commit -m "Improve greeting prompt"
git push
# Code review...

# 4. Merge and deploy
git merge main
# Deploy script runs:
# - rails db:migrate
# - rails prompt_tracker:sync  ← Syncs to production DB

# 5. New version is live
```

---

#### Staging Environment

**Behavior:**
- ✅ Mix of both (can test web UI features)
- ✅ Can activate web_ui versions (for testing)
- ✅ Manual sync

**Why:**
- Test the full workflow
- Experiment safely
- Validate before production

---

### Decision 3: Prompt Versioning Strategy

**The Question:** How do we handle prompt changes?

**Our Choice: Immutable versions**

**Rules:**
1. Once a PromptVersion has LlmResponses, its template **cannot be changed**
2. To modify a prompt, create a **new version**
3. Old versions are **deprecated**, not deleted

**Why immutable:**
- ✅ Historical accuracy (know exactly what prompt generated each response)
- ✅ Reproducibility (can replay old versions)
- ✅ Comparison (can compare v1 vs v2 performance)
- ✅ Rollback (can reactivate old version)

**Example:**
```ruby
# Version 1 is active, has 1000 responses
version1 = PromptVersion.find(1)
version1.llm_responses.count  # => 1000

# Try to change template
version1.update(template: "New template")
# => Error: "template cannot be changed after responses exist"

# Correct way: create new version
version2 = prompt.prompt_versions.create!(
  template: "New template",
  # ... other fields
)
version2.activate!  # Marks version1 as deprecated
```

---

### Decision 4: Variable Substitution

**The Question:** How do we handle dynamic content in prompts?

**Our Choice: Simple `{{variable}}` syntax**

**Why:**
- ✅ Easy to read
- ✅ Familiar (Mustache/Handlebars style)
- ✅ Simple to implement
- ✅ Clear in YAML files

**Example:**
```yaml
template: |
  Hello {{customer_name}}!

  I see you're having trouble with {{issue_category}}.
  Let me help you with that.
```

```ruby
# Rendering
version.render(customer_name: "John", issue_category: "billing")
# => "Hello John!\n\nI see you're having trouble with billing.\nLet me help you with that."
```

**Future enhancement:** Could add conditionals, loops, etc. But start simple.

---

### Decision 5: Error Handling

**The Question:** What happens when an LLM call fails?

**Our Choice: Track failures too**

**Why:**
- ✅ Debugging (see what went wrong)
- ✅ Metrics (error rates per prompt)
- ✅ Alerting (spike in errors)

**Example:**
```ruby
result = PromptTracker::LlmCallService.track(...) do |prompt|
  raise "API timeout"
end
# LlmResponse created with:
# - status: "error"
# - error_message: "API timeout"
# - error_type: "RuntimeError"
```

**Benefits:**
- "Version 2 has 5% error rate vs version 1's 1%"
- "Errors spike at 2pm every day - investigate"
- "This prompt fails with GPT-3.5 but works with GPT-4"

---

## Summary: The Complete Flow

### 1. **Setup (One Time)**
```bash
# Install gem
bundle add prompt_tracker

# Run generator
rails generate prompt_tracker:install

# Run migrations
rails prompt_tracker:install:migrations
rails db:migrate
```

### 2. **Create Prompt (Development)**
```bash
# Create YAML file
touch app/prompts/my_prompt.yml

# Edit in VSCode
# ... define template, variables, etc.

# Sync to database
rails prompt_tracker:sync

# Test in console
rails console
> PromptTracker::Prompt.find_by(name: "my_prompt")
```

### 3. **Use in Code**
```ruby
class MyController < ApplicationController
  include PromptTracker::Trackable

  def generate
    result = track_llm_call(
      "my_prompt",
      variables: { name: params[:name] },
      provider: "openai",
      model: "gpt-4",
      user_id: current_user.id
    ) do |prompt|
      OpenAI::Client.new.chat(
        messages: [{ role: "user", content: prompt }]
      )
    end

    render json: { response: result.response_text }
  end
end
```

### 4. **Deploy to Production**
```bash
# Commit prompt
git add app/prompts/my_prompt.yml
git commit -m "Add my_prompt"
git push

# Deploy (automated)
# Deploy script runs:
# - rails db:migrate
# - rails prompt_tracker:sync

# Prompt is now live in production
```

### 5. **Monitor & Improve**
```ruby
# Check performance
version = PromptVersion.find_by(prompt_name: "my_prompt", version_number: 1)
version.average_response_time  # => 1250ms
version.average_score  # => 85.5
version.response_count  # => 10000

# Create improved version
# Edit YAML file, deploy
# Compare v1 vs v2 performance
```

---

## Next Steps

After Phases 1-3 are complete, you'll have:
- ✅ Database schema for storing everything
- ✅ File-based prompt management
- ✅ Automatic LLM call tracking
- ✅ Cost calculation
- ✅ Performance metrics

**Then we build:**
- Phase 4: Evaluation system (rating responses)
- Phase 5: Web UI (browse and analyze)
- Phase 6: Analytics dashboard
- Phase 7: Experimentation features (A/B testing, playground)
- Phase 8: Tests and documentation

---

## Questions & Answers

**Q: What if I want to edit a prompt quickly in production?**
A: You can't (by design). This forces you to:
1. Test in development/staging
2. Code review the change
3. Deploy safely
This prevents accidental breaking changes.

**Q: Can I use the same prompt with different LLM providers?**
A: Yes! The prompt is provider-agnostic. You specify provider when tracking:
```ruby
track_llm_call("my_prompt", provider: "openai", ...)
track_llm_call("my_prompt", provider: "anthropic", ...)
```

**Q: How do I A/B test two versions?**
A: Specify version number:
```ruby
version = [1, 2].sample  # Random A/B split
track_llm_call("my_prompt", version: version, ...)
```

**Q: What if my YAML file has a syntax error?**
A: In development: Error when syncing (fix and retry)
In production: Deployment fails (fix before deploying)

**Q: Can I have environment-specific prompts?**
A: Yes, use different YAML files or conditionals in your code:
```ruby
prompt_name = Rails.env.production? ? "formal_greeting" : "casual_greeting"
```

---

This plan gives you a solid foundation for tracking, versioning, and improving your LLM prompts over time!
