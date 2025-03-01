# frozen_string_literal: true

module Crystalball
  class SourceDiff
    # Data object for single file in Git repo diff
    class FileDiff
      # @param [Git::DiffFile] git_diff - raw diff for a single file made by ruby-git gem
      def initialize(git_diff)
        @git_diff = git_diff
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
        if File.exist?(git_diff.path)
          git_diff.path
        else
          git_diff.path.split("/")[1..].join("/") # if we're in a monorepo setup, we need to remove the top level dir
        end
      end

      # @return new relative path to file if file was moved
      def new_relative_path
        return relative_path unless moved?

        git_diff.patch.match(/rename from.*\nrename to (.*)/)[1]
      end

      def method_missing(method, *args, &block)
        git_diff.public_send(method, *args, &block) || super
      end

      def respond_to_missing?(method, *)
        git_diff.respond_to?(method, false) || super
      end

      private

      attr_reader :git_diff
    end
  end
end
