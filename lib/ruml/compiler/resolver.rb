# frozen_string_literal: true

require 'ruml/core'
require 'ruml/compiler/ast'
require 'ruml/support/misc'

module RUML::Compiler
    class Resolver
      class Proxy < AST::Node
      end

      def initialize navigator
        @navigator = navigator
        @resolved = {}
        @proxies = {}
      end

      def find_node(node, name)
        result = @resolver.find_node(node, name)
        unless result
          result = Proxy.new({})
          result._.unresolved = AST::Node.new(
            node: node,
            name: name,
            resolver: self,
          )
          @proxies[[node.__id__, name]] = result
        end
        result
      end

      def resolve node
        return node unless Proxy === node
        meta = node._
        @navigator.find_node(meta.unresolved, meta.name)
      end
    end
  end
end
