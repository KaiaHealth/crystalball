# frozen_string_literal: true

require 'objspace'

module Crystalball
  class MapGenerator
    class AllocatedObjectsStrategy
      # Class to list object classes used during a block
      class ObjectTracker
        attr_reader :only_of

        # @param [Array<Module>] only_of - classes or modules to watch on
        def initialize(only_of: ['Object'])
          @only_of = only_of
        end

        # @yield a block to execute
        # @return [Array<Object>] classes of objects allocated during the block execution
        def used_classes_during(&block)
          created_object_classes = Set.new
          ObjectSpace.trace_object_allocations_start
          GC.start
          allocation_generation = GC.count
          gc_was_disabled = GC.disable

          yield

          whitelisted_constants.each do |constant|
            ObjectSpace.each_object(constant) do |object|
              next unless ObjectSpace.allocation_generation(object) == allocation_generation
              next if ObjectSpace.allocation_sourcefile(object) == __FILE__

              created_object_classes << object.class
            end
          end
          created_object_classes
        ensure
          GC.enable unless gc_was_disabled
          ObjectSpace.trace_object_allocations_stop
          ObjectSpace.trace_object_allocations_clear
        end

        private

        def whitelisted_constants
          @whitelisted_constants ||= only_of.map { |str| Object.const_get(str) }
        end
      end
    end
  end
end
