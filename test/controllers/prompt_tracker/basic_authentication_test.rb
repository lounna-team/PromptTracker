# frozen_string_literal: true

require "test_helper"

module PromptTracker
  class BasicAuthenticationTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    setup do
      @original_username = PromptTracker.configuration.basic_auth_username
      @original_password = PromptTracker.configuration.basic_auth_password
    end

    teardown do
      PromptTracker.configuration.basic_auth_username = @original_username
      PromptTracker.configuration.basic_auth_password = @original_password
    end

    test "should allow access when basic auth is not configured" do
      PromptTracker.configuration.basic_auth_username = nil
      PromptTracker.configuration.basic_auth_password = nil

      get prompts_path
      assert_response :success
    end

    test "should require authentication when credentials are configured" do
      PromptTracker.configuration.basic_auth_username = "admin"
      PromptTracker.configuration.basic_auth_password = "secret"

      get prompts_path
      assert_response :unauthorized
    end

    test "should allow access with correct credentials" do
      PromptTracker.configuration.basic_auth_username = "admin"
      PromptTracker.configuration.basic_auth_password = "secret"

      credentials = ActionController::HttpAuthentication::Basic.encode_credentials("admin", "secret")
      get prompts_path, headers: { "HTTP_AUTHORIZATION" => credentials }
      assert_response :success
    end

    test "should deny access with incorrect username" do
      PromptTracker.configuration.basic_auth_username = "admin"
      PromptTracker.configuration.basic_auth_password = "secret"

      credentials = ActionController::HttpAuthentication::Basic.encode_credentials("wrong", "secret")
      get prompts_path, headers: { "HTTP_AUTHORIZATION" => credentials }
      assert_response :unauthorized
    end

    test "should deny access with incorrect password" do
      PromptTracker.configuration.basic_auth_username = "admin"
      PromptTracker.configuration.basic_auth_password = "secret"

      credentials = ActionController::HttpAuthentication::Basic.encode_credentials("admin", "wrong")
      get prompts_path, headers: { "HTTP_AUTHORIZATION" => credentials }
      assert_response :unauthorized
    end

    test "should protect all routes when enabled" do
      PromptTracker.configuration.basic_auth_username = "admin"
      PromptTracker.configuration.basic_auth_password = "secret"

      # Test various routes
      get prompts_path
      assert_response :unauthorized

      get llm_responses_path
      assert_response :unauthorized

      get evaluations_path
      assert_response :unauthorized

      get analytics_root_path
      assert_response :unauthorized
    end

    test "basic_auth_enabled? returns true when both credentials are set" do
      PromptTracker.configuration.basic_auth_username = "admin"
      PromptTracker.configuration.basic_auth_password = "secret"

      assert PromptTracker.configuration.basic_auth_enabled?
    end

    test "basic_auth_enabled? returns false when username is nil" do
      PromptTracker.configuration.basic_auth_username = nil
      PromptTracker.configuration.basic_auth_password = "secret"

      assert_not PromptTracker.configuration.basic_auth_enabled?
    end

    test "basic_auth_enabled? returns false when password is nil" do
      PromptTracker.configuration.basic_auth_username = "admin"
      PromptTracker.configuration.basic_auth_password = nil

      assert_not PromptTracker.configuration.basic_auth_enabled?
    end

    test "basic_auth_enabled? returns false when both are nil" do
      PromptTracker.configuration.basic_auth_username = nil
      PromptTracker.configuration.basic_auth_password = nil

      assert_not PromptTracker.configuration.basic_auth_enabled?
    end
  end
end

