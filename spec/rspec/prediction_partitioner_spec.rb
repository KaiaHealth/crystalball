# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Crystalball::RSpec::PredictionPartitioner do
  subject(:partition) { partitioner.partition(prediction) }

  let(:partitioner) { described_class.new(workers: workers, worker_index: worker_index) }
  let(:workers) { 2 }
  let(:worker_index) { 0 }
  let(:prediction) do
    [
      './spec/models/user_spec.rb[1:1]',
      './spec/models/order_spec.rb[1:1]',
      './spec/models/user_spec.rb[1:2]',
      './spec/services/'
    ]
  end

  it 'keeps locations from the same file on one worker' do
    expect(partition).to eq(['./spec/services/', './spec/models/order_spec.rb[1:1]'])
  end

  context 'for another worker' do
    let(:worker_index) { 1 }

    it 'returns that worker prediction' do
      expect(partition).to eq(['./spec/models/user_spec.rb[1:1]', './spec/models/user_spec.rb[1:2]'])
    end
  end

  context 'with one worker' do
    let(:workers) { 1 }

    it 'keeps the prediction unchanged' do
      expect(partition).to eq(prediction)
    end
  end

  context 'when a directory contains another prediction' do
    let(:prediction) { ['./spec/services/', './spec/services/user_spec.rb[1:1]'] }

    it 'does not schedule the contained example on another worker' do
      expect(partition).to eq(['./spec/services/'])
    end
  end

  context 'with an invalid worker count' do
    let(:workers) { 0 }

    it 'fails before running RSpec' do
      expect { partition }.to raise_error(ArgumentError, 'parallel_workers must be greater than zero')
    end
  end

  context 'with an invalid worker index' do
    let(:worker_index) { 2 }

    it 'fails before running RSpec' do
      expect { partition }.to raise_error(ArgumentError, 'parallel_worker_index must identify an available worker')
    end
  end
end
