# frozen_string_literal: true

module Crystalball
  # A Git diff that always emits the standard patch format consumed by ruby-git.
  class GitDiff < ::Git::Diff
    def patch
      options = {
        patch: true,
        no_ext_diff: true,
        no_textconv: true,
        color: false,
        src_prefix: 'a/',
        dst_prefix: 'b/'
      }
      options[:path] = Array(@path) if @path

      ::Git::Commands::Diff.new(@base.execution_context).call(*[@from, @to].compact, **options).stdout
    end
  end
end
