# PromptTracker Architecture Overview

## System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         DEVELOPER WORKFLOW                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  1. Write YAML        2. Git Commit       3. Deploy        4. Sync      │
│  ┌──────────┐        ┌──────────┐       ┌──────────┐    ┌──────────┐  │
│  │ greeting │   →    │   Git    │  →    │ Production│ → │   Rake   │  │
│  │  .yml    │        │  Commit  │       │  Server   │    │  Task    │  │
│  └──────────┘        └──────────┘       └──────────┘    └──────────┘  │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                         FILE SYNC SERVICE                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Reads YAML files → Validates → Creates/Updates DB records              │
│                                                                          │
│  app/prompts/greeting.yml  →  Prompt + PromptVersion in Database       │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                         DATABASE (Source of Truth at Runtime)            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────┐                                                       │
│  │   Prompts    │  (name, description, category)                        │
│  └──────┬───────┘                                                       │
│         │ has_many                                                      │
│         ↓                                                               │
│  ┌──────────────────┐                                                   │
│  │ PromptVersions   │  (template, version_number, status)               │
│  └──────┬───────────┘                                                   │
│         │ has_many                                                      │
│         ↓                                                               │
│  ┌──────────────────┐                                                   │
│  │  LlmResponses    │  (rendered_prompt, response, metrics)             │
│  └──────┬───────────┘                                                   │
│         │ has_many                                                      │
│         ↓                                                               │
│  ┌──────────────────┐                                                   │
│  │   Evaluations    │  (score, feedback, criteria)                      │
│  └──────────────────┘                                                   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                         RUNTIME (Application Code)                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Controller/Service calls:                                              │
│                                                                          │
│  PromptTracker::LlmCallService.track(                                   │
│    prompt_name: "greeting",                                             │
│    variables: { name: "John" }                                          │
│  ) do |rendered_prompt|                                                 │
│    OpenAI.chat(prompt: rendered_prompt)  ← Your LLM call               │
│  end                                                                    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                         TRACKING FLOW                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  1. Find Prompt by name                                                 │
│  2. Get active PromptVersion                                            │
│  3. Render template with variables                                      │
│  4. Create LlmResponse (status: pending)                                │
│  5. Execute LLM call (measure time)                                     │
│  6. Update LlmResponse (status: success, store metrics)                 │
│  7. Calculate cost                                                      │
│  8. Return result                                                       │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                         ANALYSIS & EVALUATION                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Web UI:                          Analytics:                            │
│  - Browse prompts                 - Response time trends                │
│  - View versions                  - Cost analysis                       │
│  - Compare performance            - Quality scores                      │
│  - Add evaluations                - A/B test results                    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## Data Flow: From YAML to LLM Response

```
┌─────────────────┐
│  greeting.yml   │  Developer creates/edits YAML file
└────────┬────────┘
         │
         ↓
┌─────────────────┐
│  Git Commit     │  Version control tracks changes
└────────┬────────┘
         │
         ↓
┌─────────────────┐
│  Deploy         │  Code deployed to server
└────────┬────────┘
         │
         ↓
┌─────────────────┐
│  Sync Task      │  rails prompt_tracker:sync
└────────┬────────┘
         │
         ↓
┌─────────────────────────────────────────────────────────┐
│  FileSyncService                                        │
│  ┌─────────────────────────────────────────────────┐   │
│  │ 1. Read YAML: "Hello {{name}}"                  │   │
│  │ 2. Find/Create Prompt: "greeting"               │   │
│  │ 3. Compare with latest version                  │   │
│  │ 4. If changed → Create PromptVersion v2         │   │
│  │ 5. Mark v1 as deprecated                        │   │
│  └─────────────────────────────────────────────────┘   │
└────────┬────────────────────────────────────────────────┘
         │
         ↓
┌─────────────────────────────────────────────────────────┐
│  Database State                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │ Prompt: { name: "greeting", category: "support" }│  │
│  │   ├─ Version 1: "Hello {{name}}" (deprecated)   │   │
│  │   └─ Version 2: "Hi {{name}}!" (active)         │   │
│  └─────────────────────────────────────────────────┘   │
└────────┬────────────────────────────────────────────────┘
         │
         ↓
┌─────────────────────────────────────────────────────────┐
│  Application Runtime                                    │
│  ┌─────────────────────────────────────────────────┐   │
│  │ LlmCallService.track(                           │   │
│  │   prompt_name: "greeting",                      │   │
│  │   variables: { name: "John" }                   │   │
│  │ )                                               │   │
│  └─────────────────────────────────────────────────┘   │
└────────┬────────────────────────────────────────────────┘
         │
         ↓
┌─────────────────────────────────────────────────────────┐
│  LlmCallService Processing                              │
│  ┌─────────────────────────────────────────────────┐   │
│  │ 1. Find Prompt "greeting"                       │   │
│  │ 2. Get active version (v2)                      │   │
│  │ 3. Render: "Hi {{name}}!" → "Hi John!"          │   │
│  │ 4. Create LlmResponse (pending)                 │   │
│  │ 5. Call OpenAI with "Hi John!"                  │   │
│  │ 6. Receive: "Hello! How can I help?"            │   │
│  │ 7. Update LlmResponse:                          │   │
│  │    - response_text: "Hello! How can I help?"    │   │
│  │    - response_time_ms: 1250                     │   │
│  │    - tokens: 15                                 │   │
│  │    - cost_usd: 0.00045                          │   │
│  │    - status: success                            │   │
│  └─────────────────────────────────────────────────┘   │
└────────┬────────────────────────────────────────────────┘
         │
         ↓
┌─────────────────────────────────────────────────────────┐
│  Database: LlmResponse Record Created                   │
│  ┌─────────────────────────────────────────────────┐   │
│  │ {                                               │   │
│  │   prompt_version_id: 2,                         │   │
│  │   rendered_prompt: "Hi John!",                  │   │
│  │   response_text: "Hello! How can I help?",      │   │
│  │   response_time_ms: 1250,                       │   │
│  │   tokens_total: 15,                             │   │
│  │   cost_usd: 0.00045,                            │   │
│  │   provider: "openai",                           │   │
│  │   model: "gpt-4",                               │   │
│  │   status: "success"                             │   │
│  │ }                                               │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

## Component Responsibilities

### 1. YAML Files (Source of Truth for Prompts)
**Location:** `app/prompts/**/*.yml`

**Responsibility:**
- Define prompt templates
- Specify variables and their schemas
- Configure model settings
- Document prompt purpose

**Owned by:** Developers (via Git)

**Example:**
```yaml
name: customer_support_greeting
description: Initial greeting for support chats
template: |
  Hello {{customer_name}}!
  How can I help with your {{issue}}?
```

---

### 2. FileSyncService (Bridge: Files → Database)
**Location:** `app/services/prompt_tracker/file_sync_service.rb`

**Responsibility:**
- Read YAML files from disk
- Validate structure and required fields
- Create/update Prompt records
- Create new PromptVersion when template changes
- Idempotent (safe to run multiple times)

**Triggered by:**
- Rake task: `rails prompt_tracker:sync`
- Auto-sync in development (optional)
- Deployment scripts in production

**Key Logic:**
```ruby
# Pseudo-code
for each YAML file:
  prompt = find_or_create_prompt(yaml.name)
  latest_version = prompt.versions.from_files.last
  
  if latest_version.nil? OR latest_version.template != yaml.template:
    create_new_version(yaml.template)
    deprecate_old_versions()
```

---

### 3. Database Models (Runtime State)

#### Prompt
**Responsibility:** Group all versions of a prompt together

**Key Methods:**
- `active_version` - Get currently active version
- `latest_version` - Get most recent version
- `archive!` - Soft delete

#### PromptVersion
**Responsibility:** Store specific version of a prompt template

**Key Methods:**
- `render(variables)` - Substitute variables in template
- `activate!` - Make this version active
- `average_response_time` - Performance metrics
- `to_yaml_export` - Export back to YAML

**Immutability:** Template cannot change if responses exist

#### LlmResponse
**Responsibility:** Record of a single LLM API call

**Key Methods:**
- `mark_success!(...)` - Update with successful response
- `mark_error!(...)` - Update with error details
- `average_evaluation_score` - Quality metrics

**Tracks:**
- What was sent (rendered_prompt, variables)
- What came back (response_text, metadata)
- Performance (response_time_ms, tokens, cost)
- Context (user_id, session_id, environment)

#### Evaluation
**Responsibility:** Quality rating for an LLM response

**Types:**
- Human: Manual review by person
- Automated: Rule-based scoring
- LLM Judge: Another LLM evaluates the response

---

### 4. LlmCallService (Tracking Engine)
**Location:** `app/services/prompt_tracker/llm_call_service.rb`

**Responsibility:**
- Orchestrate the entire tracking flow
- Find prompt and version
- Render template with variables
- Create LlmResponse record
- Execute LLM call (via block)
- Measure performance
- Update record with results
- Handle errors gracefully

**Usage Pattern:**
```ruby
result = LlmCallService.track(
  prompt_name: "greeting",
  variables: { name: "John" }
) do |rendered_prompt|
  # Your LLM API call
  OpenAI.chat(prompt: rendered_prompt)
end
```

**Returns:**
- `llm_response` - Database record
- `response_text` - Actual LLM response
- `tracking_id` - For later reference

---

### 5. CostCalculator (Financial Tracking)
**Location:** `app/services/prompt_tracker/cost_calculator.rb`

**Responsibility:**
- Store pricing for different providers/models
- Calculate cost based on token usage
- Support fuzzy model matching (e.g., "gpt-4-0125" → "gpt-4")

**Formula:**
```
cost = (input_tokens / 1000) * input_price +
       (output_tokens / 1000) * output_price
```

---

## Environment-Specific Behavior

### Development
```
┌─────────────────────────────────────────────────┐
│ Developer edits YAML                            │
│         ↓                                       │
│ Auto-sync (optional) OR manual sync             │
│         ↓                                       │
│ Immediately available in DB                     │
│         ↓                                       │
│ Test in console/browser                         │
│         ↓                                       │
│ Iterate quickly                                 │
└─────────────────────────────────────────────────┘

Features:
✅ Auto-sync on file changes
✅ Can create prompts via web UI
✅ Can activate any version
✅ Fast iteration
```

### Production
```
┌─────────────────────────────────────────────────┐
│ Developer edits YAML locally                    │
│         ↓                                       │
│ Git commit + PR                                 │
│         ↓                                       │
│ Code review                                     │
│         ↓                                       │
│ Merge to main                                   │
│         ↓                                       │
│ Deploy (includes sync task)                     │
│         ↓                                       │
│ Prompts available in production                 │
└─────────────────────────────────────────────────┘

Features:
✅ Only file-sourced versions can be activated
✅ Manual sync via deployment
✅ Git audit trail
✅ Code review required
✅ Safe and controlled
```

---

## Key Design Principles

### 1. Prompts Are Code
- Stored in version control (Git)
- Go through code review
- Tested before deployment
- Deployed like any other code

### 2. Database Is Runtime Cache
- YAML files are source of truth
- Database is synced from files
- Database enables fast lookups at runtime
- Database stores execution history

### 3. Immutability
- PromptVersions cannot change once used
- Historical accuracy preserved
- Can always reproduce old results
- Safe to compare versions

### 4. Separation of Concerns
- **YAML**: Define prompts
- **FileSyncService**: Sync to DB
- **LlmCallService**: Track usage
- **Models**: Store data
- **Web UI**: Analyze and evaluate

### 5. Fail Fast
- Invalid YAML fails at sync time
- Missing prompts fail at call time
- Errors are tracked, not hidden
- Deployment fails if sync fails

---

## Example: Complete Lifecycle

```
Day 1: Create Prompt
├─ Developer writes greeting.yml
├─ Commits to Git
├─ Deploys to production
├─ Sync creates Prompt + PromptVersion v1
└─ Status: Active, ready to use

Day 2-30: Usage
├─ 10,000 LLM calls tracked
├─ Average response time: 1200ms
├─ Average cost: $0.002 per call
├─ 95% evaluation pass rate
└─ Total cost: $20

Day 31: Optimization
├─ Developer creates greeting_v2.yml (shorter)
├─ Tests in development
├─ Deploys to production
├─ Sync creates PromptVersion v2
├─ v1 marked as deprecated
└─ v2 becomes active

Day 32-60: Comparison
├─ v2 used for new calls
├─ Average response time: 800ms (33% faster!)
├─ Average cost: $0.0015 (25% cheaper!)
├─ 97% evaluation pass rate (better!)
└─ Decision: Keep v2, archive v1

Day 61: Rollback (if needed)
├─ v2 has issues
├─ Developer reactivates v1
├─ No code changes needed
└─ Instant rollback
```

---

This architecture provides a solid foundation for managing, tracking, and improving LLM prompts at scale!

