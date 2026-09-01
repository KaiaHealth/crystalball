# frozen_string_literal: true

require 'crystalball/source_diff/file_diff'
require 'crystalball/source_diff/formatting_checker'
require 'forwardable'

module Crystalball
  # Wrapper class representing Git source diff for given repo
  class SourceDiff
    include Enumerable
    extend Forwardable

    delegate %i[stats lines from to] => :git_diff
    alias size count

    # @param [Git::Diff] git_diff raw diff made by ruby-git gem
    def initialize(git_diff, relative_to: nil)
      @git_diff = git_diff
      @relative_to = relative_to
    end

    # Iterates over each changed file of diff
    #
    def each(&block)
      changeset.each(&block)
    end

    def empty?
      changeset.none?
    end

    # @return [Git::Repository]
    def repository
      @repository ||= git_diff.instance_variable_get(:@base)
    end

    private

    attr_reader :git_diff, :relative_to

    # TODO: Include untracked to changeset
    def changeset
      @changeset ||= git_diff.map do |diff_file|
        file_diff = FileDiff.new(diff_file, relative_to: relative_to)
        file_diff unless FormattingChecker.pure_formatting?(file_diff)
      end.compact
    end
  end
end
