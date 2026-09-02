# frozen_string_literal: true

require 'yaml'
require 'crystalball/parallel_test_environment'

module Crystalball
  class MapStorage
    # Exception class for missing map files
    class NoFilesFoundError < StandardError; end

    # YAML persistence adapter for execution map storage
    class YAMLStorage
      attr_reader :path

      class << self
        # Loads map from given path
        #
        # @param [String] path to map
        # @return [Crystalball::ExecutionMap]
        def load(path)
          meta, example_groups = *read_files(path).transpose

          guard_metadata_consistency(meta)

          Object.const_get(meta.first[:type]).new(
            metadata: meta.first,
            example_groups: merge_example_groups(example_groups)
          )
        end

        private

        def read_files(path)
          paths = path.directory? ? path.each_child.select(&:file?) : [path]

          raise NoFilesFoundError, "No files or folder exists #{path}" unless paths.any?(&:exist?)

          paths.map do |file|
            metadata, *example_groups = read(file).split("---\n").reject(&:empty?).map do |yaml|
              YAML.safe_load(yaml, permitted_classes: [Symbol])
            end

            [metadata, merge_example_groups(example_groups)]
          end
        end

        def read(path)
          path.open('r') do |file|
            file.flock(File::LOCK_SH)
            file.read
          end
        end

        def merge_example_groups(groups)
          groups.compact.each_with_object({}) do |group, result|
            group.each do |example_id, files|
              result[example_id] = (Array(result[example_id]) + Array(files)).uniq
            end
          end
        end

        def guard_metadata_consistency(metadata)
          uniq = metadata.uniq
          raise "Can't load execution maps with different metadata. Metadata: #{uniq}" if uniq.size > 1
        end
      end

      # @param [String] path to store execution map
      def initialize(path)
        @path = path
      end

      # Removes storage file
      def clear!
        path.delete if path.exist?
      end

      # Starts a new map when the stored metadata does not describe this build.
      def prepare!(metadata, preserve: ParallelTestEnvironment.parallel?)
        path.dirname.mkpath
        path.open(File::RDWR | File::CREAT, 0o644) do |file|
          file.flock(File::LOCK_EX)
          next if preserve && stored_metadata(file) == metadata

          file.rewind
          file.truncate(0)
          file.write(YAML.dump(metadata))
          file.flush
        end
      end

      # Writes data to storage file
      #
      # @param [Hash] data to write to storage file
      def dump(data)
        path.dirname.mkpath
        path.open('a') do |file|
          file.flock(File::LOCK_EX)
          file.write(YAML.dump(data))
          file.flush
        end
      end

      private

      def stored_metadata(file)
        file.rewind
        yaml = file.read.split("---\n").reject(&:empty?).first
        YAML.safe_load(yaml.to_s, permitted_classes: [Symbol])
      end
    end
  end
end
