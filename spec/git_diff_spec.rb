# frozen_string_literal: true

require 'spec_helper'

describe Crystalball::GitDiff do
  subject(:diff) { described_class.new(repository, 'HEAD^', 'HEAD') }

  let(:repository) { instance_double(Git::Repository, execution_context: execution_context) }
  let(:execution_context) { instance_double(Git::ExecutionContext::Repository) }
  let(:command) { instance_double(Git::Commands::Diff) }
  let(:result) { instance_double(Git::CommandLine::Result, stdout: 'patch') }

  before do
    allow(Git::Commands::Diff).to receive(:new).with(execution_context).and_return(command)
  end

  it 'disables external diff tools and text conversion' do
    expect(command).to receive(:call).with(
      'HEAD^',
      'HEAD',
      patch: true,
      no_ext_diff: true,
      no_textconv: true,
      color: false,
      src_prefix: 'a/',
      dst_prefix: 'b/'
    ).and_return(result)

    expect(diff.patch).to eq('patch')
  end
end
