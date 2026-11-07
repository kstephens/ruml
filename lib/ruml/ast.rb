# frozen_string_literal: true

module RUML

  # Understands a small DSL for UML modeled in subset of UML Substructure.
  module AST

    module Repr
      def [] n
        raise "#{n}" unless ::Symbol == n
        _repr[n]
      end
      def []= n, v
        raise "#{n}" unless ::Symbol == n
        _repr[n] = v
      end
      def __class__
        ::Object.instance_method(:class).bind(self).call
      end
      def __caller_locations__
        ::Object.instance_method(:caller_locations).bind(self).call
      end
      def method_missing name, *args, &blk
        name = name.to_sym
        line = __caller_locations__[0]
        raise "unexpected block" if blk
        # raise "SDKJFSKDJF" if _repr.key?("Cls2")
        case name.to_s
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
        exc = ArgumentError.new("#{self.class} : #{name} : #{e.inspect}")
        exc.set_backtrace([line.to_s, *e.backtrace])
        raise exc
      end
    end

    class Base < ::BasicObject
      include Repr
      attr_reader :_repr, :_blk, :_line_

      def initialize h, &blk
        @_repr = h
        @_blk = blk
        @_line_ = (blk&.source_location || "?:?").to_s
      end
      def self.[] *args; new(*args); end
      def nil? ; false ; end
      def to_h ; @_repr ; end
      def method ; @_repr[:method] ; end
      def inspect detail=false
        return super() if detail
        "<#{__class__}:#{object_id} #{_desc_}>"
      end
      def _desc_
        ""
      end
    end

    class Meta < Base
      ATTRS = %i[meta type name args].freeze

      def _desc_
        @_desc_ ||= ATTRS.map do |name|
          "#{name}=#{_repr[name].inspect}"
        end.join(' ').freeze
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

      def find *args # -> Node
        names = convert_path(args)
        pp(args: args, name: names)
        base = node
        if names[0] == ""
          base = root
          names.shift
        end
        names.inject(base) do | node, name |
          pp(node: node, name: name)
          found = node._.ownedElement_by_name(name)
          return unless found
          node = found
        end
      end

      def convert_path args
        names = []
        while args
          arg = args.shift
          case arg
          when ::String, ::Symbol
            names.concat(arg.to_s.split("::"))
          when ::Array
            args.unshift(arg)
          when Node
            names.concat(namespace_path(arg).map(&:name))
          else
            raise ArgumentError, "convert_path : unexpected #{arg.inspect}"
          end
        end
        names
      end

      def ownedElement_by_name name
        name = name.to_s
        node.ownedElement.find{|c| c.name == name}
      end

      def isClassMethod
        meta == :method && args.include?(:class)
      end

      def isAbstract
        meta == :class && !! node.isAbstract
      end
    end

    class Node < Base
      def _ ; @_ ||= Meta.new({node: self}) ; end

      ATTRS = %i[name].freeze

      def _desc_
        @_desc_ ||= (ATTRS.map do |name|
          "#{name}=#{self.__send__(name).inspect}"
        end.join(' ') + " " + _._desc_).freeze
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

      def responds_to? name
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
