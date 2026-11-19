# frozen_string_literal: true

require 'ruml/support/context'
require 'ruml/support/basic_object'
require 'ruml/core/navigation'

module RUML
  module Compiler
    module AST

    class Node < Support::BasicObject::Base
      def _ ; @_ ||= Meta.new({node: self}) ; end
      Support.copy_method(self, :eql?, ::Object)
      Support.copy_method(self, :is_a?, ::Object)
      def _desc_; "#{_._desc_} #{@_repr.keys}"; end
    end

    class Meta < Support::BasicObject::Base
      include ::RUML::Core::Navigation
      Support.copy_method(self, :eql?, ::Object)
      Support.copy_method(self, :is_a?, ::Object)

      ATTRS = %i[meta name args].freeze

      def _desc_
        @_desc_ ||= ATTRS.map do |name|
          "#{name}=#{_repr[name].inspect}"
        end.join(' ').freeze
      end

      def to_s
        "#{node._.meta} #{args.map(&:inspect).join(", ")}"
      end

      def node_keys
        node._repr.keys
      end

      def args_named(args, *names)
        args.zip(names) do | (arg, name)|
          node[name] = arg
        end
      end

      def args_opts(args)
        opts = args[-1]
        if ::Hash === opts
          @_repr.update(opts)
        end
      end

      def namespace_path
        super(self)
      end

      def namespace_str
        super(self)
      end

      def root_node # -> Node
        super(self)
      end

      def find *names  # !!! FIX NAME
        find_node(self, names)
      end

      def find_node(*names) # !!! FIX PROTOCOL
        path = convert_to_name_path(names)
        super(self, path)
      end

      def lookup_node ident # !!! FIX NAME
        return ident if AST::Node === ident
        find_node_scoped(self, ident)
      end

      def isStatic
        meta == :operation && args.include?(:static)
      end

      def isAbstract
        meta == :class && !! node.isAbstract
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
