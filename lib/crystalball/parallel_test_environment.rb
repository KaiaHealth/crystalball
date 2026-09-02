# frozen_string_literal: true

module Crystalball
  # Detects worker settings provided by common parallel test runners.
  module ParallelTestEnvironment
    module_function

    def worker_count(environment = ENV)
      Integer(
        environment['CRYSTALBALL_PARALLEL_WORKERS'] ||
          environment['CI_NODE_TOTAL'] ||
          environment['PARALLEL_TEST_GROUPS'] ||
          1
      )
    end

    def worker_index(environment = ENV)
      explicit_index = environment['CRYSTALBALL_PARALLEL_WORKER_INDEX']
      return Integer(explicit_index) if explicit_index
      return Integer(environment.fetch('CI_NODE_INDEX', 0)) if environment['CI_NODE_TOTAL']
      return 0 unless environment['PARALLEL_TEST_GROUPS']

      test_env_number = environment.fetch('TEST_ENV_NUMBER', '')
      test_env_number.empty? ? 0 : Integer(test_env_number) - 1
    end

    def parallel?(environment = ENV)
      worker_count(environment) > 1
    end
  end
end
