# frozen_string_literal: true

# == Schema Information
#
# Table name: prompt_tracker_prompts
#
#  archived_at                :datetime
#  category                   :string
#  created_at                 :datetime         not null
#  created_by                 :string
#  description                :text
#  id                         :bigint           not null, primary key
#  name                       :string           not null
#  score_aggregation_strategy :string           default("weighted_average")
#  tags                       :jsonb
#  updated_at                 :datetime         not null
#
require "test_helper"

module PromptTracker
  class PromptTest < ActiveSupport::TestCase
    # Setup
    def setup
      @valid_attributes = {
        name: "test_prompt",
        description: "A test prompt",
        category: "testing",
        tags: ["test", "example"],
        created_by: "test@example.com"
      }
    end

    # Validation Tests

    test "should be valid with valid attributes" do
      prompt = Prompt.new(@valid_attributes)
      assert prompt.valid?, "Prompt should be valid with valid attributes"
    end

    test "should require name" do
      prompt = Prompt.new(@valid_attributes.except(:name))
      assert_not prompt.valid?, "Prompt should not be valid without name"
      assert_includes prompt.errors[:name], "can't be blank"
    end

    test "should require unique name" do
      Prompt.create!(@valid_attributes)
      duplicate = Prompt.new(@valid_attributes)
      assert_not duplicate.valid?, "Prompt should not be valid with duplicate name"
      assert_includes duplicate.errors[:name], "has already been taken"
    end

    test "should enforce name format with lowercase letters, numbers, and underscores only" do
      valid_names = ["test", "test_prompt", "test123", "test_prompt_123"]
      valid_names.each do |name|
        prompt = Prompt.new(@valid_attributes.merge(name: name))
        assert prompt.valid?, "Name '#{name}' should be valid"
      end

      invalid_names = ["Test", "test-prompt", "test prompt", "test.prompt", "test@prompt"]
      invalid_names.each do |name|
        prompt = Prompt.new(@valid_attributes.merge(name: name))
        assert_not prompt.valid?, "Name '#{name}' should be invalid"
        assert_includes prompt.errors[:name], "must contain only lowercase letters, numbers, and underscores"
      end
    end

    test "should allow blank category" do
      prompt = Prompt.new(@valid_attributes.merge(category: nil))
      assert prompt.valid?, "Prompt should be valid with nil category"

      prompt = Prompt.new(@valid_attributes.merge(category: ""))
      assert prompt.valid?, "Prompt should be valid with empty category"
    end

    test "should enforce category format when present" do
      valid_categories = ["support", "sales_team", "content123"]
      valid_categories.each do |category|
        prompt = Prompt.new(@valid_attributes.merge(category: category))
        assert prompt.valid?, "Category '#{category}' should be valid"
      end

      invalid_categories = ["Support", "sales-team", "sales team"]
      invalid_categories.each do |category|
        prompt = Prompt.new(@valid_attributes.merge(category: category))
        assert_not prompt.valid?, "Category '#{category}' should be invalid"
      end
    end

    test "should validate tags is an array" do
      prompt = Prompt.new(@valid_attributes.merge(tags: ["valid", "array"]))
      assert prompt.valid?, "Prompt should be valid with array tags"

      prompt = Prompt.new(@valid_attributes.merge(tags: "not an array"))
      assert_not prompt.valid?, "Prompt should not be valid with non-array tags"
      assert_includes prompt.errors[:tags], "must be an array"
    end

    test "should allow nil tags" do
      prompt = Prompt.new(@valid_attributes.merge(tags: nil))
      assert prompt.valid?, "Prompt should be valid with nil tags"
    end

    # Association Tests

    test "should have many prompt_versions" do
      prompt = Prompt.create!(@valid_attributes)
      assert_respond_to prompt, :prompt_versions
      assert_equal 0, prompt.prompt_versions.count
    end

    test "should destroy associated prompt_versions when destroyed" do
      prompt = Prompt.create!(@valid_attributes)
      version = prompt.prompt_versions.create!(
        template: "Hello {{name}}",
        version_number: 1,
        status: "active",
        source: "file"
      )

      assert_difference "PromptVersion.count", -1 do
        prompt.destroy
      end
    end

    # Scope Tests

    test "active scope should return only non-archived prompts" do
      active_prompt = Prompt.create!(@valid_attributes)
      archived_prompt = Prompt.create!(@valid_attributes.merge(name: "archived_prompt", archived_at: Time.current))

      active_prompts = Prompt.active
      assert_includes active_prompts, active_prompt
      assert_not_includes active_prompts, archived_prompt
    end

    test "archived scope should return only archived prompts" do
      active_prompt = Prompt.create!(@valid_attributes)
      archived_prompt = Prompt.create!(@valid_attributes.merge(name: "archived_prompt", archived_at: Time.current))

      archived_prompts = Prompt.archived
      assert_includes archived_prompts, archived_prompt
      assert_not_includes archived_prompts, active_prompt
    end

    test "in_category scope should return prompts in specified category" do
      support_prompt = Prompt.create!(@valid_attributes.merge(name: "support_prompt", category: "support"))
      sales_prompt = Prompt.create!(@valid_attributes.merge(name: "sales_prompt", category: "sales"))

      support_prompts = Prompt.in_category("support")
      assert_includes support_prompts, support_prompt
      assert_not_includes support_prompts, sales_prompt
    end

    # Instance Method Tests

    test "active_version should return the active version" do
      prompt = Prompt.create!(@valid_attributes)
      active_version = prompt.prompt_versions.create!(
        template: "Active version",
        version_number: 2,
        status: "active",
        source: "file"
      )
      deprecated_version = prompt.prompt_versions.create!(
        template: "Old version",
        version_number: 1,
        status: "deprecated",
        source: "file"
      )

      assert_equal active_version, prompt.active_version
    end

    test "active_version should return nil when no active version exists" do
      prompt = Prompt.create!(@valid_attributes)
      assert_nil prompt.active_version
    end

    test "latest_version should return most recently created version" do
      prompt = Prompt.create!(@valid_attributes)
      first_version = prompt.prompt_versions.create!(
        template: "First",
        version_number: 1,
        status: "deprecated",
        source: "file"
      )
      sleep 0.01 # Ensure different timestamps
      latest_version = prompt.prompt_versions.create!(
        template: "Latest",
        version_number: 2,
        status: "active",
        source: "file"
      )

      assert_equal latest_version, prompt.latest_version
    end

    test "archive! should set archived_at timestamp" do
      prompt = Prompt.create!(@valid_attributes)
      assert_nil prompt.archived_at

      prompt.archive!
      assert_not_nil prompt.reload.archived_at
    end

    test "archive! should deprecate all versions" do
      prompt = Prompt.create!(@valid_attributes)
      version = prompt.prompt_versions.create!(
        template: "Test",
        version_number: 1,
        status: "active",
        source: "file"
      )

      prompt.archive!
      assert_equal "deprecated", version.reload.status
    end

    test "unarchive! should clear archived_at timestamp" do
      prompt = Prompt.create!(@valid_attributes.merge(archived_at: Time.current))
      assert_not_nil prompt.archived_at

      prompt.unarchive!
      assert_nil prompt.reload.archived_at
    end

    test "archived? should return true when archived" do
      prompt = Prompt.create!(@valid_attributes.merge(archived_at: Time.current))
      assert prompt.archived?
    end

    test "archived? should return false when not archived" do
      prompt = Prompt.create!(@valid_attributes)
      assert_not prompt.archived?
    end

    test "total_llm_calls should return count of all responses across versions" do
      prompt = Prompt.create!(@valid_attributes)
      version = prompt.prompt_versions.create!(
        template: "Test",
        version_number: 1,
        status: "active",
        source: "file"
      )

      assert_equal 0, prompt.total_llm_calls

      # This will fail until LlmResponse model is created
      # We'll update this test in the next step
    end

    test "total_cost_usd should return 0 when no responses" do
      prompt = Prompt.create!(@valid_attributes)
      assert_equal 0.0, prompt.total_cost_usd
    end

    test "average_response_time_ms should return nil when no responses" do
      prompt = Prompt.create!(@valid_attributes)
      assert_nil prompt.average_response_time_ms
    end
  end
end

