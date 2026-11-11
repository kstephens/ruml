# frozen_string_literal: true

require 'ruml/context'

module RUML
  module AST
    def self.copy_method(dst,dst_name, src_module, src_name = dst_name)
      dst.define_method(dst_name, src_module.instance_method(src_name))
    end

    module Repr
      AST.copy_method(self, :__object_id__, ::Object, :object_id)
      AST.copy_method(self, :__class__, ::Kernel, :class)
      AST.copy_method(self, :__caller_locations__, ::Kernel, :caller_locations)
      AST.copy_method(self, :__raise__, ::Kernel, :raise)

      def [] n
        raise "#{n}" unless ::Symbol == n
        _repr[n]
      end
      def []= n, v
        raise "#{n}" unless ::Symbol == n
        _repr[n] = v
      end

      def method_missing name, *args, &blk
        name = name.to_sym
        line = __caller_locations__[0]
        raise "unexpected block" if blk
        # raise "SDKJFSKDJF" if _repr.key?("Cls2")
        case name.to_s
        when /\?\Z/
          $stderr.puts("method_missing #{name.inspect} #{args.inspect}")
          super
        when /\A(.+)=\Z/
          raise "not enough args" if args.empty?
          key = $1.to_sym
          body = ::Kernel.lambda {|val| _repr[key] = val }
        else
          raise "too many args" if args.size > 1
          body = ::Kernel.lambda do | *args |
            if args.size == 1
              _repr[name] = args.first
            else
              _repr[name]
            end
          end
        end
        self.__class__.define_method(name, &body)
        self.__send__(name, *args)
      rescue => e
        exc = ::ArgumentError.new("#{self.class} : #{name} : #{e.inspect}")
        exc.set_backtrace([line.to_s, *e.backtrace])
        raise exc
      end
    end

    class Base < ::BasicObject
      include Repr
      attr_reader :_repr, :_blk, :_line_

      AST.copy_method(self, :hash, ::Object)
      AST.copy_method(self, :eql?, ::Object)

      def initialize h, &blk
        @_repr = h
        @_blk = blk
        @_line_ = (blk&.source_location || "?:?").to_s
      end
      def self.[] *args; new(*args); end
      def nil? ; false ; end
      def to_h ; @_repr ; end
      def inspect detail=false
        return super() if detail
        "<#{__class__}:#{__object_id__} #{_desc_}>"
      end
      def _desc_
        ""
      end
    end

    class Node < Base
      def _ ; @_ ||= Meta.new({node: self}) ; end
      AST.copy_method(self, :eql?, ::Object)
      def _desc_; "#{_._desc_} #{@_repr.keys}"; end
    end

    class Meta < Base
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
      def namespace_path
        node, result = self.node, []
        while node
          result << node if node.name
          node = node.namespace
        end
        result.reverse!
      end

      def namespace_str
        namespace_path.map(&:name).compact.map!(&:to_s).join("::")
      end

      def root # -> Node
        node = self.node
        while node.namespace
          node = node.namespace
        end
        node
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

      def find *args # -> Node
        names = convert_to_path(args)
        pp(args: args, name: names)
        base = node
        if names[0] == ""
          base = root
          names.shift
        else
          base = node
        end
        names.inject(base) do | node, name |
          # pp(node: node, name: name)
          found = node._.ownedElement_by_name(name)
          return unless found
          node = found
        end
      end

      def convert_to_path args
        names = []
        while arg = args.shift
          case arg
          when nil
          when ::String, ::Symbol
            names.concat(arg.to_s.split("::"))
          when ::Array
            args.unshift(arg)
          when Node
            names.concat(arg._.namespace_path.map(&:name))
          else
            __raise__ ::ArgumentError, "convert_to_path : unexpected #{arg.inspect}"
          end
        end
        names
      end

      def ownedElement_by_name name
        name = name.to_s
        node.ownedElement.find{|c| c.name == name}
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
        @context = ::RUML::Context.new(:printer)
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
      include Repr
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
