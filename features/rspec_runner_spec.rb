# frozen_string_literal: true

require_relative 'feature_helper'
require 'open3'

describe 'RSpec runner' do
  subject(:execute_runner) { run_crystalball }

  include_context 'simple git repository'
  let(:important_class_path) { root.join('lib/important_class.rb') }
  let(:other_important_class_path) { root.join('lib/other_important_class.rb') }

  map_generator_config do
    <<~CONFIG
      Crystalball::MapGenerator.start! do |c|
        c.register Crystalball::MapGenerator::CoverageStrategy.new
      end
    CONFIG
  end

  before do
    ENV['CRYSTALBALL_LOG_LEVEL'] = 'debug'
    ENV['CRYSTALBALL_LOG_FILE'] = '/dev/null'
  end

  after do
    ENV.delete('CRYSTALBALL_LOG_LEVEL')
    ENV.delete('CRYSTALBALL_LOG_FILE')
  end

  it 'does not run the default RSpec suite when the prediction is empty' do
    expect(example_count(execute_runner)).to eq(0)
  end

  it 'predicts examples' do
    change class1_path

    is_expected.to match(%r{Prediction:.*(spec/class1_spec.rb|spec/file_spec.rb)})
  end

  it 'checks limit' do
    change class1_path

    is_expected.to match(/Prediction size \d+ is over the limit \(1\)/)
      .and match(/Prediction is pruned to fit the limit!/)
      .and match(/1 example, 0 failures/)
  end

  context 'when RSpec runs across multiple workers' do
    before do
      ENV['CRYSTALBALL_EXAMPLES_LIMIT'] = '0'
      change class1_path, "#{class1_path.read}\nclass Class1\n  def parallel_evaluation_marker; end\nend\n"
    end

    after { ENV.delete('CRYSTALBALL_EXAMPLES_LIMIT') }

    it 'runs each predicted example once across all workers' do
      serial_count = example_count(run_crystalball)
      worker_counts = 2.times.map do |worker_index|
        example_count(run_crystalball('CI_NODE_TOTAL' => '2', 'CI_NODE_INDEX' => worker_index.to_s))
      end

      expect(serial_count).to be_positive
      expect(worker_counts.sum).to eq(serial_count)
    end
  end

  context 'when file, spec id, and directory are predicted' do
    before do
      ENV['CRYSTALBALL_EXAMPLES_LIMIT'] = '0'
      ENV['CRYSTALBALL_PREDICTION_BUILDER_CLASS_NAME'] = 'PredictionBuilder'
      ENV['CRYSTALBALL_REQUIRES'] = './prediction_builder'
    end

    after do
      ENV.delete('CRYSTALBALL_EXAMPLES_LIMIT')
      ENV.delete('CRYSTALBALL_PREDICTION_BUILDER_CLASS_NAME')
      ENV.delete('CRYSTALBALL_REQUIRES')
    end

    it 'runs the whole file' do
      change other_important_class_path # Adds ./spec/class2_spec.rb
      change class1_path                # Adds ./spec/class2_spec.rb[1:1:1]

      is_expected.to match(/.another_field/) # ./spec/class2_spec.rb[1:2]
    end

    context 'when the files are contained in the directories' do
      it 'runs the whole directory' do
        change important_class_path            # Adds ./spec/important_dir/
        change class2_path, 'class Class2;end' # Adds ./spec/important_dir/important_spec.rb[1:2]

        is_expected.to match(/does very specific stuff/) # ./spec/important_dir/important_spec.rb[1:1]
      end
    end

    context 'when only parts of a file need to run' do
      it 'only runs those examples' do
        change class1_path, 'class Class1;end' # Adds ./spec/important_dir/important_spec.rb[1:3]
        change class2_path, 'class Class2;end' # Adds ./spec/important_dir/important_spec.rb[1:2]

        is_expected.not_to match(/does very specific stuff/) # ./spec/important_dir/important_spec.rb[1:1]
      end
    end
  end

  def run_crystalball(environment = {})
    output, = Open3.capture2e(environment, RbConfig.ruby, '-S', 'bundle', 'exec', 'crystalball', chdir: root)
    output.strip
  end

  def example_count(output)
    output.scan(/(\d+) examples?, 0 failures/).last&.first.to_i
  end
end
