# frozen_string_literal: true

require 'crystalball/rspec/standard_prediction_builder'

module Crystalball
  module RSpec
    class Runner
      # Class for storing local runner configuration
      class Configuration
        def initialize(config = {})
          @values = {
            'execution_map_path' => 'tmp/crystalball_data.yml',
            'map_expiration_period' => 86_400,
            'repo_path' => Dir.pwd,
            'requires' => [],
            'diff_from' => 'HEAD',
            'diff_to' => nil,
            'runner_class_name' => 'Crystalball::RSpec::Runner',
            'prediction_builder_class_name' => 'Crystalball::RSpec::StandardPredictionBuilder',
            'log_level' => :info,
            'log_file' => 'log/crystalball.log'
          }.merge(config)
        end

        def to_h
          dynamic_values = {}
          excluded_methods = %i[detected_parallel_worker_index run_requires values raw_value]
          (private_methods - Object.private_instance_methods - excluded_methods).each do |method|
            dynamic_values[method.to_s] = send(method)
          end

          values.merge(dynamic_values)
        end

        def [](key)
          respond_to?(key, true) ? send(key) : raw_value(key)
        end

        private

        def raw_value(key)
          ENV.fetch("CRYSTALBALL_#{key.to_s.upcase}", values[key])
        end

        def prediction_builder_class
          @prediction_builder_class ||= begin
            run_requires

            Object.const_get(self['prediction_builder_class_name'])
          end
        end

        def runner_class
          @runner_class ||= begin
            run_requires

            Object.const_get(self['runner_class_name'])
          end
        end

        def execution_map_path
          @execution_map_path ||= Pathname.new(raw_value('execution_map_path'))
        end

        def repo_path
          @repo_path ||= Pathname.new(raw_value('repo_path'))
        end

        def log_file
          @log_file ||= Pathname.new(raw_value('log_file'))
        end

        def parallel_workers
          @parallel_workers ||= Integer(
            raw_value('parallel_workers') || ENV['CI_NODE_TOTAL'] || ENV['PARALLEL_TEST_GROUPS'] || 1
          )
        end

        def parallel_worker_index
          @parallel_worker_index ||= Integer(
            raw_value('parallel_worker_index') || detected_parallel_worker_index
          )
        end

        def detected_parallel_worker_index
          return ENV.fetch('CI_NODE_INDEX', 0) if ENV['CI_NODE_TOTAL']
          return 0 unless ENV['PARALLEL_TEST_GROUPS']

          test_env_number = ENV.fetch('TEST_ENV_NUMBER', '')
          test_env_number.empty? ? 0 : Integer(test_env_number) - 1
        end

        attr_reader :values

        def run_requires
          Array(self['requires']).each { |f| require f }
        end
      end
    end
  end
end
