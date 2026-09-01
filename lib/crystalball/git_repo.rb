# frozen_string_literal: true

require 'git'
require 'crystalball/git_diff'
require 'crystalball/source_diff'

module Crystalball
  # Wrapper class representing Git repository
  class GitRepo
    attr_reader :repo_path

    class << self
      # @return [Crystalball::GitRepo] instance for given path
      def open(repo_path)
        path = Pathname(repo_path)
        new(path) if exists?(path)
      end

      # Check if given path is under git control (contains .git folder)
      def exists?(path)
        path.join('.git').directory?
      end
    end

    # @param [Pathname] repo_path path to repository root folder
    def initialize(repo_path)
      @repo_path = repo_path
    end

    # Proxy all unknown calls to `Git` object
    def method_missing(method, *args, &block)
      repo.public_send(method, *args, &block)
    end

    def respond_to_missing?(method, *)
      repo.respond_to?(method, false)
    end

    def current_commit
      repo.gcommit('HEAD').sha
    end

    # Creates diff
    #
    # @param [String] from starting commit to build a diff. Default: HEAD
    # @param [String] to ending commit to build a diff. Default: nil, will build diff of uncommitted changes
    # @return [SourceDiff]
    def diff(from = 'HEAD', to = nil)
      SourceDiff.new(GitDiff.new(repo, from, to), relative_to: diff_root)
    end

    private

    def diff_root
      repository_root = repo.dir.expand_path
      current_directory = Pathname.pwd
      current_directory.to_s.start_with?("#{repository_root}/") ? current_directory : repository_root
    end

    def repo
      @repo ||= Git.open(repo_path)
    end
  end
end
