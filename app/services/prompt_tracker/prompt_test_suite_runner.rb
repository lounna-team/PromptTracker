# frozen_string_literal: true

module PromptTracker
  # Service for running a test suite.
  #
  # Executes all enabled tests in a suite and aggregates results.
  #
  # @example Run a suite
  #   runner = PromptTestSuiteRunner.new(suite, metadata: { triggered_by: "ci" })
  #   suite_run = runner.run! do |rendered_prompt|
  #     # Call LLM API
  #     OpenAI::Client.new.chat(messages: [{ role: "user", content: rendered_prompt }])
  #   end
  #
  # @example Run suite for specific version
  #   runner = PromptTestSuiteRunner.new(suite, version: version)
  #   suite_run = runner.run!
  #
  class PromptTestSuiteRunner
    attr_reader :prompt_test_suite, :version, :metadata, :suite_run

    # Initialize the suite runner
    #
    # @param prompt_test_suite [PromptTestSuite] the suite to run
    # @param version [PromptVersion, nil] optional specific version to test
    # @param metadata [Hash] additional metadata for the suite run
    def initialize(prompt_test_suite, version: nil, metadata: {})
      @prompt_test_suite = prompt_test_suite
      @version = version
      @metadata = metadata || {}
      @suite_run = nil
    end

    # Run the test suite
    #
    # @yield [rendered_prompt] optional block to execute LLM calls
    # @yieldparam rendered_prompt [String] the rendered prompt
    # @yieldreturn [Object] the LLM response object
    # @return [PromptTestSuiteRun] the suite run result
    def run!(&block)
      start_time = Time.current

      # Get enabled tests
      tests = prompt_test_suite.enabled_tests

      # Create suite run record
      @suite_run = PromptTestSuiteRun.create!(
        prompt_test_suite: prompt_test_suite,
        status: "running",
        total_tests: tests.count,
        triggered_by: metadata[:triggered_by],
        metadata: metadata
      )

      # Run each test
      test_results = run_tests(tests, &block)

      # Calculate totals
      passed_count = test_results.count { |r| r.passed? }
      failed_count = test_results.count { |r| r.failed? }
      error_count = test_results.count { |r| r.error? }
      skipped_count = test_results.count { |r| r.skipped? }

      # Calculate total duration and cost
      total_duration = test_results.sum { |r| r.execution_time_ms || 0 }
      total_cost = test_results.sum { |r| r.cost_usd || 0 }

      # Determine suite status
      status = determine_suite_status(passed_count, failed_count, error_count, tests.count)

      # Update suite run
      execution_time = ((Time.current - start_time) * 1000).to_i
      @suite_run.update!(
        status: status,
        passed_tests: passed_count,
        failed_tests: failed_count,
        error_tests: error_count,
        skipped_tests: skipped_count,
        total_duration_ms: total_duration,
        total_cost_usd: total_cost
      )

      @suite_run.reload
    end

    private

    # Run all tests in the suite
    #
    # @param tests [ActiveRecord::Relation<PromptTest>] tests to run
    # @yield [rendered_prompt] optional block to execute LLM calls
    # @return [Array<PromptTestRun>] array of test run results
    def run_tests(tests, &block)
      results = []

      tests.each do |test|
        # Determine which version to test
        test_version = version || test.prompt.active_version || test.prompt.latest_version

        if test_version.nil?
          # Skip test if no version available
          test_run = PromptTestRun.create!(
            prompt_test: test,
            prompt_version: test.prompt.prompt_versions.first,
            prompt_test_suite_run: @suite_run,
            status: "skipped",
            passed: false,
            error_message: "No version available to test"
          )
          results << test_run
          next
        end

        # Run the test
        runner = PromptTestRunner.new(test, test_version, metadata: metadata)
        test_run = runner.run!(&block)

        # Associate with suite run
        test_run.update!(prompt_test_suite_run: @suite_run)

        results << test_run
      end

      results
    end

    # Determine suite status based on test results
    #
    # @param passed_count [Integer] number of passed tests
    # @param failed_count [Integer] number of failed tests
    # @param error_count [Integer] number of error tests
    # @param total_count [Integer] total number of tests
    # @return [String] suite status
    def determine_suite_status(passed_count, failed_count, error_count, total_count)
      if error_count.positive?
        "error"
      elsif failed_count.zero? && passed_count == total_count
        "passed"
      elsif failed_count.positive?
        "failed"
      else
        "partial"
      end
    end
  end
end
