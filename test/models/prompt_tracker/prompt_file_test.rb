# frozen_string_literal: true

require "test_helper"
require "tempfile"

module PromptTracker
  class PromptFileTest < ActiveSupport::TestCase
    def setup
      @valid_yaml = <<~YAML
        name: test_prompt
        description: A test prompt
        category: testing
        tags:
          - test
          - example
        template: |
          Hello {{name}}!
          How are you doing with {{topic}}?
        variables:
          - name: name
            type: string
            required: true
          - name: topic
            type: string
            required: false
        model_config:
          temperature: 0.7
          max_tokens: 150
        notes: This is a test prompt
      YAML

      @temp_file = Tempfile.new(["test_prompt", ".yml"])
      @temp_file.write(@valid_yaml)
      @temp_file.close
    end

    def teardown
      @temp_file.unlink if @temp_file
    end

    # Initialization Tests

    test "should initialize with path" do
      file = PromptFile.new(@temp_file.path)
      assert_equal @temp_file.path, file.path
    end

    # Validation Tests

    test "should be valid with valid YAML" do
      file = PromptFile.new(@temp_file.path)
      assert file.valid?, "File should be valid. Errors: #{file.errors.join(', ')}"
    end

    test "should be invalid if file does not exist" do
      file = PromptFile.new("/nonexistent/file.yml")
      assert_not file.valid?
      assert_includes file.errors.first, "File does not exist"
    end

    test "should be invalid with invalid YAML syntax" do
      temp = Tempfile.new(["invalid", ".yml"])
      temp.write("invalid: yaml: syntax:")
      temp.close

      file = PromptFile.new(temp.path)
      assert_not file.valid?
      assert file.errors.any? { |e| e.include?("Invalid YAML syntax") }

      temp.unlink
    end

    test "should be invalid if YAML is not a hash" do
      temp = Tempfile.new(["array", ".yml"])
      temp.write("- item1\n- item2")
      temp.close

      file = PromptFile.new(temp.path)
      assert_not file.valid?
      assert_includes file.errors.first, "must contain a hash"

      temp.unlink
    end

    test "should require name field" do
      yaml = @valid_yaml.gsub("name: test_prompt", "")
      temp = create_temp_file(yaml)

      file = PromptFile.new(temp.path)
      assert_not file.valid?
      assert file.errors.any? { |e| e.include?("Missing required field: name") }

      temp.unlink
    end

    test "should require template field" do
      yaml = @valid_yaml.gsub(/template:.*How are you doing with.*?\n/m, "")
      temp = create_temp_file(yaml)

      file = PromptFile.new(temp.path)
      assert_not file.valid?
      assert file.errors.any? { |e| e.include?("Missing required field: template") }

      temp.unlink
    end

    test "should validate name format" do
      yaml = @valid_yaml.gsub("name: test_prompt", "name: Invalid Name")
      temp = create_temp_file(yaml)

      file = PromptFile.new(temp.path)
      assert_not file.valid?
      assert file.errors.any? { |e| e.include?("lowercase letters, numbers, and underscores") }

      temp.unlink
    end

    test "should validate tags is an array" do
      yaml = @valid_yaml.gsub("tags:\n  - test\n  - example", "tags: not_an_array")
      temp = create_temp_file(yaml)

      file = PromptFile.new(temp.path)
      assert_not file.valid?
      assert file.errors.any? { |e| e.include?("tags' must be an array") }

      temp.unlink
    end

    test "should validate variables is an array" do
      yaml = @valid_yaml.gsub(/variables:.*?model_config:/m, "variables: not_an_array\nmodel_config:")
      temp = create_temp_file(yaml)

      file = PromptFile.new(temp.path)
      assert_not file.valid?
      assert file.errors.any? { |e| e.include?("variables' must be an array") }

      temp.unlink
    end

    test "should validate model_config is a hash" do
      yaml = @valid_yaml.gsub("model_config:\n  temperature: 0.7\n  max_tokens: 150", "model_config: not_a_hash")
      temp = create_temp_file(yaml)

      file = PromptFile.new(temp.path)
      assert_not file.valid?
      assert file.errors.any? { |e| e.include?("model_config' must be a hash") }

      temp.unlink
    end

    test "should validate template variables match schema" do
      yaml = <<~YAML
        name: test_prompt
        template: "Hello {{name}} and {{unknown_var}}"
        variables:
          - name: name
            type: string
      YAML
      temp = create_temp_file(yaml)

      file = PromptFile.new(temp.path)
      assert_not file.valid?
      assert file.errors.any? { |e| e.include?("not defined in schema") && e.include?("unknown_var") }

      temp.unlink
    end

    # Accessor Tests

    test "should return name" do
      file = PromptFile.new(@temp_file.path)
      assert_equal "test_prompt", file.name
    end

    test "should return template" do
      file = PromptFile.new(@temp_file.path)
      assert_includes file.template, "Hello {{name}}"
    end

    test "should return description" do
      file = PromptFile.new(@temp_file.path)
      assert_equal "A test prompt", file.description
    end

    test "should return category" do
      file = PromptFile.new(@temp_file.path)
      assert_equal "testing", file.category
    end

    test "should return tags" do
      file = PromptFile.new(@temp_file.path)
      assert_equal ["test", "example"], file.tags
    end

    test "should return empty array for tags if not specified" do
      yaml = @valid_yaml.gsub("tags:\n  - test\n  - example\n", "")
      temp = create_temp_file(yaml)

      file = PromptFile.new(temp.path)
      assert_equal [], file.tags

      temp.unlink
    end

    test "should return variables" do
      file = PromptFile.new(@temp_file.path)
      assert_equal 2, file.variables.length
      assert_equal "name", file.variables.first["name"]
    end

    test "should return model_config" do
      file = PromptFile.new(@temp_file.path)
      assert_equal 0.7, file.model_config["temperature"]
      assert_equal 150, file.model_config["max_tokens"]
    end

    test "should return notes" do
      file = PromptFile.new(@temp_file.path)
      assert_equal "This is a test prompt", file.notes
    end

    # File Info Tests

    test "exists? should return true for existing file" do
      file = PromptFile.new(@temp_file.path)
      assert file.exists?
    end

    test "exists? should return false for non-existing file" do
      file = PromptFile.new("/nonexistent/file.yml")
      assert_not file.exists?
    end

    test "last_modified should return file mtime" do
      file = PromptFile.new(@temp_file.path)
      assert_instance_of Time, file.last_modified
    end

    test "last_modified should return nil for non-existing file" do
      file = PromptFile.new("/nonexistent/file.yml")
      assert_nil file.last_modified
    end

    # Conversion Tests

    test "to_h should return hash with prompt and version data" do
      file = PromptFile.new(@temp_file.path)
      hash = file.to_h

      assert_equal "test_prompt", hash[:prompt][:name]
      assert_equal "A test prompt", hash[:prompt][:description]
      assert_equal "testing", hash[:prompt][:category]
      assert_equal ["test", "example"], hash[:prompt][:tags]

      assert_includes hash[:version][:template], "Hello {{name}}"
      assert_equal 2, hash[:version][:variables_schema].length
      assert_equal 0.7, hash[:version][:model_config]["temperature"]
      assert_equal "This is a test prompt", hash[:version][:notes]
      assert_equal "file", hash[:version][:source]
    end

    test "summary should return readable summary" do
      # Mock the configuration
      PromptTracker.configure do |config|
        config.prompts_path = File.dirname(@temp_file.path)
      end

      file = PromptFile.new(@temp_file.path)
      summary = file.summary

      assert_includes summary, "test_prompt"
      assert_includes summary, File.basename(@temp_file.path)
    end

    private

    def create_temp_file(content)
      temp = Tempfile.new(["test", ".yml"])
      temp.write(content)
      temp.close
      temp
    end
  end
end

