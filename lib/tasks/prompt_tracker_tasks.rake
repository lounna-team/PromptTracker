# frozen_string_literal: true

namespace :prompt_tracker do
  desc "Sync all prompt YAML files to database"
  task sync: :environment do
    puts "🔄 Syncing prompt files to database..."
    puts "   Prompts directory: #{PromptTracker.configuration.prompts_path}"
    puts ""

    result = PromptTracker::FileSyncService.sync_all

    if result[:synced] > 0 || result[:skipped] > 0
      puts "✅ Sync complete!"
      puts "   Synced: #{result[:synced]}"
      puts "   Skipped (no changes): #{result[:skipped]}"
      puts "   Errors: #{result[:errors]}"
      puts ""

      if result[:synced] > 0
        puts "📝 Details:"
        result[:details].select { |d| d[:action] }.each do |detail|
          action_emoji = detail[:action] == "created" ? "➕" : "🔄"
          puts "   #{action_emoji} #{detail[:prompt]} v#{detail[:version]} (#{detail[:action]})"
        end
      end

      if result[:errors] > 0
        puts ""
        puts "❌ Errors:"
        result[:details].select { |d| d[:error] }.each do |detail|
          puts "   #{File.basename(detail[:file])}: #{detail[:error]}"
        end
        exit 1
      end
    else
      puts "ℹ️  No prompt files found in #{PromptTracker.configuration.prompts_path}"
    end
  end

  namespace :sync do
    desc "Force sync all prompt files (creates new versions even if unchanged)"
    task force: :environment do
      puts "🔄 Force syncing all prompt files..."
      puts "   This will create new versions for all prompts"
      puts ""

      result = PromptTracker::FileSyncService.sync_all(force: true)

      puts "✅ Force sync complete!"
      puts "   Synced: #{result[:synced]}"
      puts "   Errors: #{result[:errors]}"
      puts ""

      if result[:synced] > 0
        puts "📝 Details:"
        result[:details].select { |d| d[:action] }.each do |detail|
          puts "   🔄 #{detail[:prompt]} v#{detail[:version]}"
        end
      end

      if result[:errors] > 0
        puts ""
        puts "❌ Errors:"
        result[:details].select { |d| d[:error] }.each do |detail|
          puts "   #{File.basename(detail[:file])}: #{detail[:error]}"
        end
        exit 1
      end
    end
  end

  desc "Validate all prompt YAML files without syncing"
  task validate: :environment do
    puts "🔍 Validating prompt files..."
    puts "   Prompts directory: #{PromptTracker.configuration.prompts_path}"
    puts ""

    result = PromptTracker::FileSyncService.validate_all

    if result[:valid]
      puts "✅ All #{result[:total]} prompt files are valid!"
      puts ""
      puts "📝 Files:"
      result[:files].each do |file|
        puts "   ✓ #{file[:name]} (#{File.basename(file[:path])})"
      end
    else
      puts "❌ Validation failed!"
      puts "   Valid: #{result[:files].length}"
      puts "   Invalid: #{result[:errors].length}"
      puts ""
      puts "Errors:"
      result[:errors].each do |error|
        puts "   #{File.basename(error[:path])}:"
        error[:errors].each do |err|
          puts "     - #{err}"
        end
      end
      exit 1
    end
  end

  desc "List all prompt files"
  task list: :environment do
    puts "📁 Prompt files in #{PromptTracker.configuration.prompts_path}:"
    puts ""

    files = PromptTracker::FileSyncService.find_prompt_files

    if files.empty?
      puts "   No prompt files found"
    else
      files.each do |file|
        relative_path = file.sub(PromptTracker.configuration.prompts_path + "/", "")
        puts "   📄 #{relative_path}"
      end
      puts ""
      puts "Total: #{files.length} files"
    end
  end

  desc "Show prompt statistics"
  task stats: :environment do
    puts "📊 PromptTracker Statistics"
    puts "=" * 50
    puts ""

    # Prompts
    total_prompts = PromptTracker::Prompt.count
    active_prompts = PromptTracker::Prompt.active.count
    archived_prompts = PromptTracker::Prompt.archived.count

    puts "Prompts:"
    puts "  Total: #{total_prompts}"
    puts "  Active: #{active_prompts}"
    puts "  Archived: #{archived_prompts}"
    puts ""

    # Versions
    total_versions = PromptTracker::PromptVersion.count
    active_versions = PromptTracker::PromptVersion.active.count
    file_versions = PromptTracker::PromptVersion.from_files.count
    web_versions = PromptTracker::PromptVersion.from_web_ui.count

    puts "Versions:"
    puts "  Total: #{total_versions}"
    puts "  Active: #{active_versions}"
    puts "  From files: #{file_versions}"
    puts "  From web UI: #{web_versions}"
    puts ""

    # Responses
    total_responses = PromptTracker::LlmResponse.count
    successful_responses = PromptTracker::LlmResponse.successful.count
    failed_responses = PromptTracker::LlmResponse.failed.count

    puts "LLM Responses:"
    puts "  Total: #{total_responses}"
    puts "  Successful: #{successful_responses}"
    puts "  Failed: #{failed_responses}"

    if total_responses > 0
      success_rate = (successful_responses.to_f / total_responses * 100).round(1)
      puts "  Success rate: #{success_rate}%"

      avg_time = PromptTracker::LlmResponse.successful.average(:response_time_ms)
      puts "  Avg response time: #{avg_time.to_i}ms" if avg_time

      total_cost = PromptTracker::LlmResponse.sum(:cost_usd)
      puts "  Total cost: $#{total_cost.round(4)}" if total_cost > 0
    end
    puts ""

    # Evaluations
    total_evaluations = PromptTracker::Evaluation.count
    human_evaluations = PromptTracker::Evaluation.by_humans.count
    automated_evaluations = PromptTracker::Evaluation.automated.count
    llm_judge_evaluations = PromptTracker::Evaluation.by_llm_judge.count

    puts "Evaluations:"
    puts "  Total: #{total_evaluations}"
    puts "  Human: #{human_evaluations}"
    puts "  Automated: #{automated_evaluations}"
    puts "  LLM Judge: #{llm_judge_evaluations}"

    if total_evaluations > 0
      avg_score = PromptTracker::Evaluation.average(:score)
      puts "  Avg score: #{avg_score.round(2)}" if avg_score
    end
  end
end
