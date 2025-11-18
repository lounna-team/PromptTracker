# Mock/Real LLM Mode Implementation Summary

## Overview

Implemented a flexible system that allows switching between **mock mode** (for development) and **real API mode** (for production testing) using environment variables.

## What Was Implemented

### 1. Environment Configuration

**Files Modified:**
- `.env` - Added configuration variables
- `.env.example` - Added template with all supported providers

**New Variables:**
```bash
PROMPT_TRACKER_USE_REAL_LLM=false  # Toggle between mock/real mode

# Provider API Keys
OPENAI_API_KEY=...
ANTHROPIC_API_KEY=...
GOOGLE_API_KEY=...
COHERE_API_KEY=...
```

### 2. LLM Client Service

**New File:** `app/services/prompt_tracker/llm_client_service.rb`

A unified service for making LLM API calls to multiple providers:

**Features:**
- ✅ OpenAI integration (fully implemented)
- ⏳ Anthropic support (placeholder)
- ⏳ Google support (placeholder)
- ⏳ Cohere support (placeholder)
- Error handling for missing API keys
- Error handling for API failures
- Standardized response format

**Usage:**
```ruby
response = LlmClientService.call(
  provider: "openai",
  model: "gpt-4",
  prompt: "Hello!",
  temperature: 0.7
)
```

### 3. Controller Updates

**File Modified:** `app/controllers/prompt_tracker/prompt_tests_controller.rb`

**Changes:**
- Added `use_real_llm?` helper method
- Added `call_real_llm` method for real API calls
- Updated `run` action to check mode and call appropriate method
- Added error handling for API errors

**Flow:**
```
Test Run → Check PROMPT_TRACKER_USE_REAL_LLM
         ↓
    Real Mode? → Yes → LlmClientService.call → Real API
         ↓
         No → generate_mock_llm_response → Mock
```

### 4. Test Runner Updates

**File Modified:** `app/services/prompt_tracker/prompt_test_runner.rb`

**Changes:**
- Added `use_real_llm?` helper method
- Added `call_real_llm_judge` method for real judge evaluations
- Updated `run_evaluators` to support both mock and real judge calls
- Automatic provider detection based on model name

**LLM Judge Flow:**
```
Judge Evaluation → Check PROMPT_TRACKER_USE_REAL_LLM
                ↓
           Real Mode? → Yes → LlmClientService.call → Real Judge
                ↓
                No → generate_mock_judge_response → Mock Judge
```

### 5. Comprehensive Tests

**New File:** `spec/services/prompt_tracker/llm_client_service_spec.rb`

**Test Coverage:**
- ✅ OpenAI API calls with correct parameters
- ✅ Response formatting and parsing
- ✅ max_tokens parameter handling
- ✅ API error handling
- ✅ Missing API key detection
- ✅ Unsupported provider errors
- ✅ Anthropic placeholder behavior

**All 7 specs passing!**

### 6. Dependencies

**File Modified:** `Gemfile`

**Added:**
- `ruby-openai` (~> 6.3) - OpenAI API client
- `anthropic` (~> 0.1) - Anthropic API client (optional)

### 7. Documentation

**New File:** `docs/LLM_API_INTEGRATION.md`

Comprehensive documentation covering:
- Configuration instructions
- Supported providers
- Mock vs Real mode comparison
- Usage examples
- Cost considerations
- Error handling
- Architecture overview

## How to Use

### Development (Mock Mode)

```bash
# .env
PROMPT_TRACKER_USE_REAL_LLM=false
```

- No API calls made
- Free and fast
- Perfect for development

### Production Testing (Real Mode)

```bash
# .env
PROMPT_TRACKER_USE_REAL_LLM=true
OPENAI_API_KEY=sk-proj-your-key-here
```

- Real API calls to OpenAI
- Costs money
- Use for validation

### Switching Modes

1. Update `.env` file
2. Restart Rails server
3. Run tests - mode is automatically detected

## Benefits

### For Development
- ✅ Fast iteration without API costs
- ✅ No API keys needed for basic development
- ✅ Predictable mock responses for testing

### For Production
- ✅ Real LLM validation when needed
- ✅ Support for multiple providers
- ✅ Easy switching between providers
- ✅ Proper error handling and reporting

### For Testing
- ✅ Comprehensive test coverage
- ✅ No real API calls in test suite
- ✅ Mocked responses for predictable tests

## Architecture Highlights

### Separation of Concerns
- **LlmClientService**: Handles all provider API calls
- **Controller**: Decides mock vs real mode
- **TestRunner**: Orchestrates test execution
- **Evaluators**: Focus on evaluation logic

### Extensibility
- Easy to add new providers (Anthropic, Google, Cohere)
- Consistent interface across all providers
- Provider-specific logic isolated in LlmClientService

### Error Handling
- Missing API keys caught early
- API errors reported clearly to users
- Graceful degradation

## Next Steps (Optional)

1. **Implement Anthropic Integration**
   - Add Anthropic gem
   - Implement `call_anthropic` method
   - Add tests

2. **Implement Google Integration**
   - Add Google Gemini client
   - Implement `call_google` method
   - Add tests

3. **Add Cost Tracking**
   - Track API costs per test run
   - Display costs in UI
   - Set budget limits

4. **Add Caching**
   - Cache LLM responses for identical prompts
   - Reduce API costs
   - Speed up repeated tests

## Files Changed

### New Files
- `app/services/prompt_tracker/llm_client_service.rb`
- `spec/services/prompt_tracker/llm_client_service_spec.rb`
- `docs/LLM_API_INTEGRATION.md`

### Modified Files
- `.env`
- `.env.example`
- `Gemfile`
- `app/controllers/prompt_tracker/prompt_tests_controller.rb`
- `app/services/prompt_tracker/prompt_test_runner.rb`

## Testing

All tests passing:
```bash
bundle exec rspec spec/services/prompt_tracker/llm_client_service_spec.rb
# 7 examples, 0 failures
```

