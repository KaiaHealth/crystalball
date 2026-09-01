# frozen_string_literal: true

module Crystalball
  class SourceDiff
    # Data object for single file in Git repo diff
    class FileDiff
      # @param [Git::DiffFile] git_diff - raw diff for a single file made by ruby-git gem
      def initialize(git_diff, relative_to: nil)
        @git_diff = git_diff
        @relative_to = relative_to
      end

      def moved?
        !(git_diff.patch =~ /rename from.*\nrename to/).nil?
      end

      def modified?
        !moved? && git_diff.type == 'modified'
      end

      def deleted?
        git_diff.type == 'deleted'
      end

      def new?
        git_diff.type == 'new'
      end

      # @return relative path to file
      def relative_path
        normalize_path(git_diff.path)
      end

      # @return new relative path to file if file was moved
      def new_relative_path
        return relative_path unless moved?

        normalize_path(git_diff.patch.match(/rename from.*\nrename to (.*)/)[1])
      end

      def method_missing(method, *args, &block)
        git_diff.public_send(method, *args, &block) || super
      end

      def respond_to_missing?(method, *)
        git_diff.respond_to?(method, false) || super
      end

      private

      attr_reader :git_diff, :relative_to

      def normalize_path(path)
        return path unless relative_to

        repository_root = git_diff.instance_variable_get(:@base).dir
        repository_root.join(path).relative_path_from(relative_to).to_s
      end
    end
  end
end
