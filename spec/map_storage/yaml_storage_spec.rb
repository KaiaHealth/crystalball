# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

describe Crystalball::MapStorage::YAMLStorage do
  subject { described_class.new(path) }

  let(:path) { Pathname('map.yml') }

  def allow_path_exists(bool)
    allow(path).to receive(:exist?).with(no_args).and_return(bool)
  end

  describe '.load' do
    subject(:map) { described_class.load(path) }

    it 'loads yaml metadata and example_groups from file if it exists' do
      allow_path_exists true
      allow(described_class).to receive(:read).with(path).and_return(
        {commit: '123', type: 'Crystalball::ExecutionMap'}.to_yaml +
          {'UID1' => %w[1 2 3]}.to_yaml +
          {'UID100' => %w[a b c]}.to_yaml
      )
      expect(map).to be_a Crystalball::ExecutionMap
      expect(map.example_groups).to eq('UID1' => %w[1 2 3], 'UID100' => %w[a b c])
      expect(map.commit).to eq '123'
    end

    it 'merges files from repeated example groups' do
      allow_path_exists true
      allow(described_class).to receive(:read).with(path).and_return(
        {commit: '123', type: 'Crystalball::ExecutionMap'}.to_yaml +
          {'UID1' => %w[1 2]}.to_yaml +
          {'UID1' => %w[2 3]}.to_yaml
      )

      expect(map.example_groups).to eq('UID1' => %w[1 2 3])
    end

    context 'when path is a directory' do
      let(:path) { instance_double('Pathname', directory?: true) }
      let(:file1) { instance_double('Pathname', file?: true, exist?: true, read: file_content1) }
      let(:file_content1) do
        {commit: '123', type: 'Crystalball::ExecutionMap'}.to_yaml + {'UID1' => %w[1 2 3]}.to_yaml
      end
      let(:file2) { instance_double('Pathname', file?: true, exist?: true, read: file_content2) }
      let(:file_content2) do
        {commit: '123', type: 'Crystalball::ExecutionMap'}.to_yaml + {'UID100' => %w[a b c]}.to_yaml
      end
      let(:subdir) { instance_double('Pathname', directory?: true, file?: false) }

      before do
        allow_path_exists true
        allow(path).to receive(:each_child).and_return [file1, file2, subdir]
        allow(described_class).to receive(:read).with(file1).and_return(file_content1)
        allow(described_class).to receive(:read).with(file2).and_return(file_content2)
      end

      it 'load every file in directory' do
        expect(map).to be_a Crystalball::ExecutionMap
        expect(map.example_groups).to eq('UID1' => %w[1 2 3], 'UID100' => %w[a b c])
        expect(map.commit).to eq '123'
      end

      context 'when one file has no example groups' do
        let(:file_content2) { {commit: '123', type: 'Crystalball::ExecutionMap'}.to_yaml }

        it 'ignores that file' do
          expect(map.example_groups).to eq('UID1' => %w[1 2 3])
        end
      end

      context 'when metadata info is inconsistent' do
        let(:file_content2) do
          {commit: '456', type: 'Crystalball::ExecutionMap'}.to_yaml + {'UID100' => %w[a b c]}.to_yaml
        end

        specify do
          expect { subject }.to raise_error(/Can't load execution maps with different metadata/)
        end
      end
    end

    context 'when path is empty' do
      let(:path) { instance_double('Pathname', directory?: false, exist?: false) }

      it 'fails with NoFilesFoundError' do
        expect { map }.to raise_error Crystalball::MapStorage::NoFilesFoundError
      end

      context 'and is a directory' do
        let(:path) { instance_double('Pathname', directory?: true, each_child: []) }
        it 'fails with NoFilesFoundError' do
          expect { map }.to raise_error Crystalball::MapStorage::NoFilesFoundError
        end
      end
    end
  end

  describe '#clear!' do
    it 'does nothing when file does not exist' do
      allow_path_exists(false)
      subject.clear!
    end

    it 'deletes file when it exists' do
      allow_path_exists(true)
      expect(path).to receive(:delete).with(no_args)
      subject.clear!
    end
  end

  describe '#dump' do
    let(:data) { {'metadata' => 'world', 'example_groups' => 'hello'} }
    let(:file) { instance_double(File, flock: true, write: true, flush: true) }

    before { allow(path).to receive(:open).with('a').and_yield(file) }

    it 'appends map to file' do
      expect(file).to receive(:flock).with(File::LOCK_EX).ordered
      expect(file).to receive(:write).with("---\nmetadata: world\nexample_groups: hello\n").ordered
      expect(file).to receive(:flush).with(no_args).ordered
      subject.dump(data)
    end
  end

  describe '#prepare!' do
    let(:metadata) { {type: 'Crystalball::ExecutionMap', commit: '123'} }

    around do |example|
      Dir.mktmpdir do |directory|
        @temporary_map_path = Pathname(directory).join('nested', 'map.yml')
        example.run
      end
    end

    let(:path) { @temporary_map_path }

    it 'creates storage with the map metadata' do
      subject.prepare!(metadata)

      expect(described_class.load(path).commit).to eq('123')
    end

    it 'preserves map data for parallel workers when metadata matches' do
      subject.prepare!(metadata)
      subject.dump('UID1' => %w[1 2])

      subject.prepare!(metadata, preserve: true)

      expect(described_class.load(path).example_groups).to eq('UID1' => %w[1 2])
    end

    it 'replaces map data for a nonparallel rebuild' do
      subject.prepare!(metadata)
      subject.dump('UID1' => %w[1 2])

      subject.prepare!(metadata)

      expect(described_class.load(path).example_groups).to be_empty
    end

    it 'replaces map data when metadata changes' do
      subject.prepare!(metadata)
      subject.dump('UID1' => %w[1 2])

      subject.prepare!(metadata.merge(commit: '456'))

      map = described_class.load(path)
      expect(map.commit).to eq('456')
      expect(map.example_groups).to be_empty
    end
  end
end
