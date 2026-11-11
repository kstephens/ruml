# frozen_string_literal: true

require 'ruml/compiler/ast'

module RUML
  class Compiler
    module AST
    module Native
      def self.lookup_module name
        name.split("::").inject(::Object) do | mod, name |
          return unless ::Module === mod
          mod.const_get(name)
          end
        end
      end
      def self.build(mod)
        case mod
        when nil, RElement then mod
        when ::Class       then RClass.new(mod)
        when ::Module      then RNamespace.new(mod)
        when String        then __construct(lookup_module(mod))
        else raise
        end
      end

      class RElement < Node
        def initialize native
          @_native = native
          super({})
        end
      end

      class RNamespace < RElement
        def namespace
          @namespace ||= Native.build(@_native.to_s.sub(/::[^:]+\Z/, ''))
        end
        def ownedElement
          @ownedElement ||= @_native.constants.map{|n| @_native.const_get(n)}.select{|v| ::Module === v}
        end
      end
      class RClass < RNamespace
        def ownedOperation

        end
      end

      class ROperation < RElement
        def parameter

        end
      end
      class RParameter < RElement
      end
    end
  end
end
