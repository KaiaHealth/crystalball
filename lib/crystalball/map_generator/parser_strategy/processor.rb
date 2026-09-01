# frozen_string_literal: true

require 'prism'

module Crystalball
  class MapGenerator
    class ParserStrategy
      # Parses source files and reports constant definitions and interactions.
      class Processor
        def consts_defined_in(path)
          result = Prism.parse(File.read(path))
          return [] unless result.success?

          definitions = []
          collect_definitions(result.value, nil, definitions)
          definitions
        end

        def consts_interacted_with_in(path)
          result = Prism.parse(File.read(path))
          return [] unless result.success?

          interactions = []
          collect_interactions(result.value, nil, interactions)
          interactions
        end

        private

        def collect_definitions(node, scope, definitions)
          case node
          when Prism::ClassNode, Prism::ModuleNode
            class_or_module_name = qualified_constant_name(node.constant_path, scope)
            definitions << class_or_module_name
            collect_definitions(node.body, class_or_module_name, definitions) if node.body
          when Prism::ConstantWriteNode, Prism::ConstantPathWriteNode
            definitions << qualified_constant_name(node, scope)
            node.compact_child_nodes.each { |child| collect_definitions(child, scope, definitions) }
          else
            node.compact_child_nodes.each { |child| collect_definitions(child, scope, definitions) }
          end
        end

        def collect_interactions(node, scope, interactions)
          case node
          when Prism::ClassNode
            interactions << qualified_constant_name(node.superclass, scope) if constant_node?(node.superclass)
            nested_scope = qualified_constant_name(node.constant_path, scope)
            collect_interactions(node.body, nested_scope, interactions) if node.body
          when Prism::ModuleNode
            nested_scope = qualified_constant_name(node.constant_path, scope)
            collect_interactions(node.body, nested_scope, interactions) if node.body
          when Prism::CallNode
            interactions << constant_name(node.receiver).delete_prefix('::') if constant_node?(node.receiver)
            node.compact_child_nodes.each { |child| collect_interactions(child, scope, interactions) }
          else
            node.compact_child_nodes.each { |child| collect_interactions(child, scope, interactions) }
          end
        end

        def constant_node?(node)
          node.is_a?(Prism::ConstantReadNode) || node.is_a?(Prism::ConstantPathNode)
        end

        def qualified_constant_name(node, scope)
          name = constant_name(node)
          return name.delete_prefix('::') if name.start_with?('::')
          return "#{scope}::#{name}" if scope

          name
        end

        def constant_name(node)
          target = node.is_a?(Prism::ConstantPathWriteNode) ? node.target : node
          target.full_name
        end
      end
    end
  end
end
