# LLM API Integration

PromptTracker supports both **mock mode** (for development/testing) and **real API mode** (for production testing with actual LLM providers).

## Configuration

### Environment Variables

The behavior is controlled by environment variables in your `.env` file:

```bash
# Set to 'true' to use real LLM API calls, 'false' for mock responses
PROMPT_TRACKER_USE_REAL_LLM=false

# Provider API Keys
OPENAI_API_KEY=your_openai_api_key_here
ANTHROPIC_API_KEY=your_anthropic_api_key_here
GOOGLE_API_KEY=your_google_api_key_here
COHERE_API_KEY=your_cohere_api_key_here
```

### Switching Between Mock and Real Mode

**Mock Mode (Default):**
```bash
PROMPT_TRACKER_USE_REAL_LLM=false
```
- No API calls are made
- Generates realistic mock responses
- Free and fast
- Perfect for development and testing

**Real API Mode:**
```bash
PROMPT_TRACKER_USE_REAL_LLM=true
```
- Makes actual API calls to LLM providers
- Requires valid API keys
- Costs money (based on provider pricing)
- Use for production testing and validation

## Supported Providers

### OpenAI (Fully Implemented)

**Supported Models:**
- `gpt-4`
- `gpt-4-turbo`
- `gpt-3.5-turbo`
- `o1-preview`
- `o1-mini`

**Configuration:**
```bash
OPENAI_API_KEY=sk-proj-...
```

**Example Test Configuration:**
```json
{
  "provider": "openai",
  "model": "gpt-4",
  "temperature": 0.7,
  "max_tokens": 1000
}
```

### Anthropic (Coming Soon)

**Supported Models:**
- `claude-3-opus-20240229`
- `claude-3-sonnet-20240229`
- `claude-3-haiku-20240307`

**Configuration:**
```bash
ANTHROPIC_API_KEY=sk-ant-...
```

### Google (Coming Soon)

**Supported Models:**
- `gemini-pro`
- `gemini-pro-vision`

**Configuration:**
```bash
GOOGLE_API_KEY=...
```

### Cohere (Coming Soon)

**Configuration:**
```bash
COHERE_API_KEY=...
```

## How It Works

### 1. LLM Response Generation

When you run a test, the system:

**Mock Mode:**
1. Generates a fake response based on the prompt
2. Returns immediately (no API call)
3. Response includes mock text indicating it's a mock

**Real Mode:**
1. Calls `LlmClientService` with provider and model config
2. Makes actual API call to the configured provider
3. Returns real LLM response
4. Tracks tokens and costs

### 2. LLM Judge Evaluations

When using the `llm_judge` evaluator:

**Mock Mode:**
1. Generates mock evaluation scores (80-95% range)
2. Returns structured evaluation response
3. No API call made

**Real Mode:**
1. Builds evaluation prompt with criteria
2. Calls real LLM API (using `judge_model` from config)
3. Parses real evaluation response
4. Extracts scores and feedback

## Usage Examples

### Running Tests in Mock Mode

1. Set environment variable:
```bash
PROMPT_TRACKER_USE_REAL_LLM=false
```

2. Run test from UI or console:
```ruby
runner = PromptTestRunner.new(test, version)
test_run = runner.run!
```

3. Mock responses are generated automatically

### Running Tests in Real Mode

1. Configure API key:
```bash
OPENAI_API_KEY=sk-proj-your-key-here
PROMPT_TRACKER_USE_REAL_LLM=true
```

2. Restart Rails server to load new environment variables

3. Run test - real API calls will be made

### Cost Considerations

**Real API Mode Costs:**
- OpenAI GPT-4: ~$0.03 per 1K prompt tokens, ~$0.06 per 1K completion tokens
- OpenAI GPT-3.5: ~$0.0015 per 1K prompt tokens, ~$0.002 per 1K completion tokens

**Tips to Minimize Costs:**
- Use mock mode for development
- Only enable real mode when validating production prompts
- Use cheaper models (gpt-3.5-turbo) for initial testing
- Set `max_tokens` limits in test configurations

## Error Handling

The system handles various error scenarios:

**Missing API Key:**
```
API key missing: OPENAI_API_KEY environment variable not set.
Please configure your API keys in .env file.
```

**API Errors:**
```
LLM API error: OpenAI API error: Rate limit exceeded
```

**Unsupported Provider:**
```
Provider 'unknown_provider' is not supported.
Supported providers: openai, anthropic, google, cohere
```

## Architecture

### LlmClientService

Central service for making LLM API calls:

```ruby
response = LlmClientService.call(
  provider: "openai",
  model: "gpt-4",
  prompt: "Hello, world!",
  temperature: 0.7,
  max_tokens: 100
)

response[:text]   # => "Hello! How can I help you today?"
response[:usage]  # => { prompt_tokens: 10, completion_tokens: 8, total_tokens: 18 }
response[:model]  # => "gpt-4-0613"
response[:raw]    # => Full API response
```

### Integration Points

1. **PromptTestsController**: Checks `use_real_llm?` and calls appropriate method
2. **PromptTestRunner**: Handles both LLM responses and judge evaluations
3. **LlmClientService**: Unified interface for all provider API calls

## Testing

Run the LlmClientService specs:

```bash
bundle exec rspec spec/services/prompt_tracker/llm_client_service_spec.rb
```

All specs use mocks and don't make real API calls.

