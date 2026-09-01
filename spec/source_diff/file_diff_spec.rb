# frozen_string_literal: true

require 'spec_helper'

describe Crystalball::SourceDiff::FileDiff do
  subject(:file_diff) { described_class.new(diff_file) }
  let(:repository) { instance_double(Git::Repository, dir: Pathname.pwd) }
  let(:diff_file) { Git::Diff::DiffFile.new(repository, type: type, path: 'lib/crystalball.rb') }
  let(:type) {}

  %i[modified deleted new].each do |type|
    context "##{type}?" do
      subject { file_diff.send("#{type}?") }

      it { is_expected.to be_falsey }

      context 'with correct type' do
        let(:type) { type.to_s }

        it { is_expected.to be_truthy }
      end
    end
  end

  context '#moved?' do
    subject { file_diff.send('moved?') }

    it { is_expected.to be_falsey }

    context 'with correct patch' do
      let(:diff_file) { Git::Diff::DiffFile.new(repository, type: 'modified', path: 'lib/crystalball.rb', patch: "rename from lib/crystalball.rb\nrename to lib/crystalball_new.rb") }

      it { is_expected.to be_truthy }
    end
  end

  describe '#relative_path' do
    subject { file_diff.relative_path }
    it { is_expected.to eq('lib/crystalball.rb') }

    context 'in a monorepo subdirectory' do
      subject { described_class.new(diff_file, relative_to: Pathname('/repo/app')).relative_path }

      let(:repository) { instance_double(Git::Repository, dir: Pathname('/repo')) }
      let(:diff_file) { Git::Diff::DiffFile.new(repository, type: type, path: 'app/lib/crystalball.rb') }

      it { is_expected.to eq('lib/crystalball.rb') }
    end
  end

  describe '#new_relative_path' do
    subject { file_diff.new_relative_path }

    context 'when file not moved' do
      it { is_expected.to eq('lib/crystalball.rb') }
    end

    context 'when file moved' do
      let(:diff_file) { Git::Diff::DiffFile.new(repository, type: 'modified', path: 'lib/crystalball.rb', patch: "rename from lib/crystalball.rb\nrename to lib/crystalball_new.rb") }

      it { is_expected.to eq('lib/crystalball_new.rb') }
    end
  end

  describe '#method_missing' do
    it 'delegates missing methods to DiffFile' do
      expect(file_diff.path).to eq('lib/crystalball.rb')
      expect(file_diff.method(:path).call).to eq('lib/crystalball.rb')
    end
  end
end
