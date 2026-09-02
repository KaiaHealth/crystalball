# frozen_string_literal: true

require 'crystalball/prediction'

module Crystalball
  module RSpec
    # Splits a prediction between parallel workers without splitting a spec file.
    class PredictionPartitioner
      def initialize(workers:, worker_index:)
        @workers = Integer(workers)
        @worker_index = Integer(worker_index)

        raise ArgumentError, 'parallel_workers must be greater than zero' unless @workers.positive?
        return if @worker_index.between?(0, @workers - 1)

        raise ArgumentError, 'parallel_worker_index must identify an available worker'
      end

      def partition(prediction)
        return prediction unless workers > 1

        prediction_groups(prediction).each_with_index.filter_map do |group, index|
          group if index % workers == worker_index
        end.flatten
      end

      private

      attr_reader :workers, :worker_index

      def prediction_groups(prediction)
        Prediction.new(prediction).compact.group_by { |location| location.split('[', 2).first }.values
      end
    end
  end
end
