# PromptTracker

A comprehensive Rails 7.2 engine for managing, tracking, and analyzing LLM prompts with a "prompts as code" philosophy.

## Features

✅ **Prompt Management** - Version control for prompts with file-based storage
✅ **Response Tracking** - Track all LLM responses with metrics (tokens, cost, latency)
✅ **Evaluation System** - Automated and manual evaluation with multiple evaluator types
✅ **A/B Testing** - Built-in A/B testing with statistical analysis
✅ **Analytics Dashboard** - Comprehensive analytics and visualizations
✅ **Background Jobs** - Async evaluation processing with retry logic
✅ **Web UI** - Bootstrap 5.3 interface for managing prompts and viewing analytics

## Test Coverage

- **~683 tests** across Minitest and RSpec
- **89.64% line coverage**, 69.64% branch coverage
- **100% coverage** of controllers, models, services, and jobs
- See [TESTING.md](TESTING.md) for details

## Quick Start

### Run All Tests

```bash
bin/test_all
```

### View Coverage Report

```bash
open coverage/index.html
```

## Usage

See the comprehensive documentation:
- [TESTING.md](TESTING.md) - Testing guide
- [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) - Implementation details
- [docs/EVALUATOR_SYSTEM_DESIGN.md](docs/EVALUATOR_SYSTEM_DESIGN.md) - Evaluator system design

## Installation
Add this line to your application's Gemfile:

```ruby
gem "prompt_tracker"
```

And then execute:
```bash
$ bundle
```

Or install it yourself as:
```bash
$ gem install prompt_tracker
```

## Contributing
Contribution directions go here.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
