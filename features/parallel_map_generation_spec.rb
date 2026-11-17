# frozen_string_literal: true

require_relative 'feature_helper'

RSpec.describe 'Parallel map generation' do
  include_context 'simple git repository'

  map_generator_config do
    <<~CONFIG
      Crystalball::MapGenerator.start! do |config|
        config.register Crystalball::MapGenerator::CoverageStrategy.new
      end
    CONFIG
  end

  it 'keeps the map data produced by every worker' do
    map_path = root.join('tmp/crystalball_data.yml')
    Crystalball::MapStorage::YAMLStorage.new(map_path).clear!

    results = 2.times.map do |worker_index|
      Thread.new do
        run_map_generation(
          "spec/class#{worker_index + 1}_spec.rb",
          environment: {'CI_NODE_TOTAL' => '2', 'CI_NODE_INDEX' => worker_index.to_s}
        )
      end
    end.map(&:value)

    expect(results).to all be(true)

    example_groups = Crystalball::MapStorage::YAMLStorage.load(map_path).example_groups
    expect(example_groups).to include(
      a_string_starting_with('./spec/class1_spec.rb'),
      a_string_starting_with('./spec/class2_spec.rb')
    )
  end
end
