# frozen_string_literal: true

require 'rails_helper'

describe Crystalball::Rails::Predictor::ModifiedSchema do
  subject(:predictor) { described_class.new(tables_map_path: tables_map_path) }
  let(:tables_map_path) { 'tables_map.yml' }
  let(:tables_map) { {} }

  before do
    allow(Crystalball::MapStorage::YAMLStorage).to receive(:load).with(Pathname(tables_map_path)) { tables_map }
  end

  it '#tables_map' do
    expect(subject.tables_map).to eq tables_map
  end

  describe '#call' do
    subject { predictor.call(diff, execution_map) }
    let(:diff) { [] }
    let(:execution_map) { instance_double('Crystalball::MapGenerator::ExecutionMap') }

    it { is_expected.to eq [] }

    context 'when schema was changed' do
      let(:tables_map) { {'dummies' => [model_path]} }
      let(:diff) { Crystalball::SourceDiff.new(nil) }
      let(:schema_diff) { Crystalball::SourceDiff::FileDiff.new(Git::Diff::DiffFile.new(repository, path: schema_path)) }
      let(:repository) { instance_double(Git::Repository, dir: Pathname.pwd) }
      let(:schema_path) { 'db/schema.rb' }
      let(:execution_map) { instance_double('Crystalball::MapGenerator::ExecutionMap', example_groups: example_groups) }
      let(:example_groups) { {spec_file: [model_path]} }
      let(:model_path) { 'dummy.rb' }

      before do
        allow(diff).to receive(:changeset) { [schema_diff] }
        allow(diff).to receive(:repository) { repository }
        allow(diff).to receive(:from) { 'from' }
        allow(diff).to receive(:to) { 'to' }
        allow(repository).to receive(:show).with('from', schema_path) { 'schema_before' }
        allow(repository).to receive(:show).with('to', schema_path) { 'schema_after' }
        allow(Crystalball::Rails::Helpers::SchemaDefinitionParser).to receive(:parse).with('schema_before') { {'dummies' => 1} }
        allow(Crystalball::Rails::Helpers::SchemaDefinitionParser).to receive(:parse).with('schema_after') { {'dummies' => 2} }
      end

      it 'predicts example' do
        is_expected.to eq [:spec_file]
      end

      context 'localy' do
        before do
          allow(diff).to receive('to') { nil }
          allow(repository).to receive(:dir) { Pathname.pwd }
          allow(File).to receive(:read).with(File.join(Pathname.pwd, schema_path)) { 'schema_after' }
        end

        it 'predicts example' do
          is_expected.to eq [:spec_file]
        end
      end
    end
  end
end
