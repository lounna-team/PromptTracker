# frozen_string_literal: true

require "test_helper"

module PromptTracker
  class PromptVersionTest < ActiveSupport::TestCase
    # Setup
    def setup
      @prompt = Prompt.create!(
        name: "test_prompt",
        description: "A test prompt",
        category: "testing"
      )

      @valid_attributes = {
        prompt: @prompt,
        template: "Hello {{name}}, how can I help with {{issue}}?",
        version_number: 1,
        status: "active",
        source: "file",
        variables_schema: [
          { "name" => "name", "type" => "string", "required" => true },
          { "name" => "issue", "type" => "string", "required" => false }
        ],
        model_config: { "temperature" => 0.7, "max_tokens" => 150 }
      }
    end

    # Validation Tests

    test "should be valid with valid attributes" do
      version = PromptVersion.new(@valid_attributes)
      assert version.valid?, "PromptVersion should be valid with valid attributes"
    end

    test "should require template" do
      version = PromptVersion.new(@valid_attributes.except(:template))
      assert_not version.valid?
      assert_includes version.errors[:template], "can't be blank"
    end

    test "should auto-set version_number if not provided" do
      version = PromptVersion.new(@valid_attributes.except(:version_number))
      assert version.valid?, "PromptVersion should auto-set version_number"
      assert_equal 1, version.version_number, "First version should be 1"
    end

    test "should require positive version_number" do
      version = PromptVersion.new(@valid_attributes.merge(version_number: 0))
      assert_not version.valid?

      version = PromptVersion.new(@valid_attributes.merge(version_number: -1))
      assert_not version.valid?
    end

    test "should require unique version_number per prompt" do
      PromptVersion.create!(@valid_attributes)
      duplicate = PromptVersion.new(@valid_attributes)
      assert_not duplicate.valid?
      assert_includes duplicate.errors[:version_number], "already exists for this prompt"
    end

    test "should allow same version_number for different prompts" do
      PromptVersion.create!(@valid_attributes)

      other_prompt = Prompt.create!(name: "other_prompt")
      other_version = PromptVersion.new(@valid_attributes.merge(prompt: other_prompt))
      assert other_version.valid?
    end

    test "should require valid status" do
      PromptVersion::STATUSES.each do |status|
        version = PromptVersion.new(@valid_attributes.merge(status: status))
        assert version.valid?, "Status '#{status}' should be valid"
      end

      version = PromptVersion.new(@valid_attributes.merge(status: "invalid"))
      assert_not version.valid?
      assert_includes version.errors[:status], "is not included in the list"
    end

    test "should require valid source" do
      PromptVersion::SOURCES.each do |source|
        version = PromptVersion.new(@valid_attributes.merge(source: source))
        assert version.valid?, "Source '#{source}' should be valid"
      end

      version = PromptVersion.new(@valid_attributes.merge(source: "invalid"))
      assert_not version.valid?
      assert_includes version.errors[:source], "is not included in the list"
    end

    test "should validate variables_schema is an array" do
      version = PromptVersion.new(@valid_attributes.merge(variables_schema: []))
      assert version.valid?

      version = PromptVersion.new(@valid_attributes.merge(variables_schema: "not an array"))
      assert_not version.valid?
      assert_includes version.errors[:variables_schema], "must be an array"
    end

    test "should validate model_config is a hash" do
      version = PromptVersion.new(@valid_attributes.merge(model_config: {}))
      assert version.valid?

      version = PromptVersion.new(@valid_attributes.merge(model_config: "not a hash"))
      assert_not version.valid?
      assert_includes version.errors[:model_config], "must be a hash"
    end

    # Auto-increment version_number Tests

    test "should auto-increment version_number when not provided" do
      version1 = PromptVersion.create!(@valid_attributes.except(:version_number))
      assert_equal 1, version1.version_number

      version2 = PromptVersion.create!(@valid_attributes.except(:version_number))
      assert_equal 2, version2.version_number

      version3 = PromptVersion.create!(@valid_attributes.except(:version_number))
      assert_equal 3, version3.version_number
    end

    # Scope Tests

    test "active scope should return only active versions" do
      active = PromptVersion.create!(@valid_attributes.merge(status: "active"))
      deprecated = PromptVersion.create!(@valid_attributes.merge(version_number: 2, status: "deprecated"))

      active_versions = PromptVersion.active
      assert_includes active_versions, active
      assert_not_includes active_versions, deprecated
    end

    test "deprecated scope should return only deprecated versions" do
      active = PromptVersion.create!(@valid_attributes.merge(status: "active"))
      deprecated = PromptVersion.create!(@valid_attributes.merge(version_number: 2, status: "deprecated"))

      deprecated_versions = PromptVersion.deprecated
      assert_includes deprecated_versions, deprecated
      assert_not_includes deprecated_versions, active
    end

    test "draft scope should return only draft versions" do
      active = PromptVersion.create!(@valid_attributes.merge(status: "active"))
      draft = PromptVersion.create!(@valid_attributes.merge(version_number: 2, status: "draft"))

      draft_versions = PromptVersion.draft
      assert_includes draft_versions, draft
      assert_not_includes draft_versions, active
    end

    test "from_files scope should return only file-sourced versions" do
      file_version = PromptVersion.create!(@valid_attributes.merge(source: "file"))
      web_version = PromptVersion.create!(@valid_attributes.merge(version_number: 2, source: "web_ui"))

      file_versions = PromptVersion.from_files
      assert_includes file_versions, file_version
      assert_not_includes file_versions, web_version
    end

    test "by_version scope should order by version_number descending" do
      v1 = PromptVersion.create!(@valid_attributes.merge(version_number: 1))
      v3 = PromptVersion.create!(@valid_attributes.merge(version_number: 3))
      v2 = PromptVersion.create!(@valid_attributes.merge(version_number: 2))

      versions = PromptVersion.by_version.to_a
      assert_equal [v3, v2, v1], versions
    end

    # Render Method Tests

    test "render should substitute variables in template" do
      version = PromptVersion.create!(@valid_attributes)
      rendered = version.render(name: "John", issue: "billing")
      assert_equal "Hello John, how can I help with billing?", rendered
    end

    test "render should handle missing optional variables" do
      version = PromptVersion.create!(@valid_attributes)
      rendered = version.render(name: "John")
      assert_equal "Hello John, how can I help with {{issue}}?", rendered
    end

    test "render should raise error for missing required variables" do
      version = PromptVersion.create!(@valid_attributes)
      error = assert_raises(ArgumentError) do
        version.render(issue: "billing") # missing required 'name'
      end
      assert_match(/Missing required variables: name/, error.message)
    end

    test "render should work with symbol keys" do
      version = PromptVersion.create!(@valid_attributes)
      rendered = version.render(name: "John", issue: "billing")
      assert_equal "Hello John, how can I help with billing?", rendered
    end

    test "render should work with string keys" do
      version = PromptVersion.create!(@valid_attributes)
      rendered = version.render("name" => "John", "issue" => "billing")
      assert_equal "Hello John, how can I help with billing?", rendered
    end

    # Activate Method Tests

    test "activate! should set status to active" do
      version = PromptVersion.create!(@valid_attributes.merge(status: "draft"))
      version.activate!
      assert_equal "active", version.reload.status
    end

    test "activate! should deprecate other versions of same prompt" do
      v1 = PromptVersion.create!(@valid_attributes.merge(version_number: 1, status: "active"))
      v2 = PromptVersion.create!(@valid_attributes.merge(version_number: 2, status: "draft"))

      v2.activate!

      assert_equal "deprecated", v1.reload.status
      assert_equal "active", v2.reload.status
    end

    test "activate! should not affect versions of other prompts" do
      other_prompt = Prompt.create!(name: "other_prompt")
      other_version = PromptVersion.create!(@valid_attributes.merge(prompt: other_prompt, status: "active"))

      version = PromptVersion.create!(@valid_attributes)
      version.activate!

      assert_equal "active", other_version.reload.status
    end

    # Deprecate Method Tests

    test "deprecate! should set status to deprecated" do
      version = PromptVersion.create!(@valid_attributes.merge(status: "active"))
      version.deprecate!
      assert_equal "deprecated", version.reload.status
    end

    # Status Check Methods

    test "active? should return true for active versions" do
      version = PromptVersion.create!(@valid_attributes.merge(status: "active"))
      assert version.active?
    end

    test "deprecated? should return true for deprecated versions" do
      version = PromptVersion.create!(@valid_attributes.merge(status: "deprecated"))
      assert version.deprecated?
    end

    test "draft? should return true for draft versions" do
      version = PromptVersion.create!(@valid_attributes.merge(status: "draft"))
      assert version.draft?
    end

    test "from_file? should return true for file-sourced versions" do
      version = PromptVersion.create!(@valid_attributes.merge(source: "file"))
      assert version.from_file?
    end

    # Immutability Tests

    test "should allow template changes when no responses exist" do
      version = PromptVersion.create!(@valid_attributes)
      version.template = "New template"
      assert version.valid?
      assert version.save
    end

    # Note: This test will work once LlmResponse model is created
    # test "should prevent template changes when responses exist" do
    #   version = PromptVersion.create!(@valid_attributes)
    #   version.llm_responses.create!(...)
    #   version.template = "New template"
    #   assert_not version.valid?
    #   assert_includes version.errors[:template], "cannot be changed after responses exist"
    # end

    # Export Method Tests

    test "to_yaml_export should return hash with all fields" do
      version = PromptVersion.create!(@valid_attributes)
      export = version.to_yaml_export

      assert_equal @prompt.name, export["name"]
      assert_equal @prompt.description, export["description"]
      assert_equal @prompt.category, export["category"]
      assert_equal version.template, export["template"]
      assert_equal version.variables_schema, export["variables"]
      assert_equal version.model_config, export["model_config"]
    end
  end
end
