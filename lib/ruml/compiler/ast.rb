# frozen_string_literal: true

require 'ruml/support/context'
require 'ruml/support/basic_object'
require 'ruml/core/navigation'

module RUML
  module Compiler
    module AST
      def self.build_desc(obj, attrs)
        attrs.map do |name|
          obj.key?(name) ? "#{name}=#{obj[name].inspect}" : nil
        end.compact.join(' ')
      end

      class Node < Support::BasicObject::Base
      ATTRS = %i[name].freeze
      def _ ; @_ ||= Meta.new({node: self}) ; end
      Support.copy_method(self, :eql?, ::Object)
      Support.copy_method(self, :is_a?, ::Object)
      def _desc_; "#{_._desc_} #{AST.build_desc(_repr, ATTRS)}"; end
    end

    class Meta < Support::BasicObject::Base
      include ::RUML::Core::Navigation
      Support.copy_method(self, :eql?, ::Object)
      Support.copy_method(self, :is_a?, ::Object)

      ATTRS = %i[ns metatype].freeze

      def _desc_
        AST.build_desc(_repr, ATTRS)
      end

      def to_s
        "#{node._.metatype} #{args.map(&:inspect).join(", ")}"
      end
    end

    class Printer
      def initialize opts = {}
        @out = opts[:out] || $stdout
        @context = ::RUML::Support::Context.new(:printer)
      end

      def call node
        walk node
      end

      def walk node
        @context.with(node) do
          self << "  " * @context.depth << node._.to_s << "\n"
          node._.node_children.each do | child |
            walk child
          end
        end
      end

      def << x
        @out << x.to_s
        self
      end
    end

    class Navigable < ::BasicObject
      include Support::BasicObject::Repr
      attr_reader :_repr, :_path

      def self.[] v
        __coerce__(v, [])
      end

      def self.__coerce__ v, path
        case v
        when Navigable
          v
        when ::Hash, ::Array
          Navigable.new(v, path)
        else
          v
        end
      end

      def initialize repr, path
        @_repr = repr
        @_path = path
      end

      def [] i
        __coerce__(@_repr[i],  @_path + [i])
      end

      def respond_to? name
        ::Hash == @_repr && @_repr.key?(name)
      end

      def method_missing name, *args, &blk
        raise unless args.empty?
        raise if blk
        case @_repr
        when ::Hash, Navigable
          Navigable.new(@_repr[name], @_path + [name])
        else
          @_repr.__send__(name)
        end
      end
    end
  end
end
end
