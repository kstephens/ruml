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

    class Node < Base
      ATTRS = %i[meta type name args].freeze

      def _ ; @_ ||= Base.new({}) ; end

      def _desc_
        @_desc_ ||= ATTRS.map do |name|
          "#{name}=#{_repr[name].inspect}"
        end.join(' ').freeze
      end

      def _namespace_path
        node, path = self, []
        while node
          path << node
          node = node.namespace
        end
        path.reverse!
      end

      def _namespace_str
        _namespace_path.map(&:name).compact.map(&:to_s).join("::")
      end

      def _root
        node = self
        while node.namespace
          node = node.namespace
        end
        node
      end

      def _find *names
        names = names[0].to_s.split("::") if ::String === names[0]
        base = self
        if names[0] == ""
          base = _root
          names.shift
        end
        names.inject(base) do | node, name |
          return unless node
          node.ownedElement.find{|c| c.name == name.to_s}
        end
      end

      def _isClassMethod
        meta == :method && args.include?(:class)
      end

      def _isAbstract
        meta == :class && !! isAbstract
        # while node
        #   return true if node.meta == :class && node.isAbstract
        #   node = node.namespace
        # end
        # false
      end
    end

    class Navigable < ::BasicObject
      include Repr
      attr_reader :_repr, :_path
      def initialize repr, path = []
        @_repr = repr
        @_path = path
      end

      def [] i
        case v = @_repr[i]
        when ::Hash, ::Array, Navigable
          Navigable.new(v, @_path + [i])
        else
          v
        end
      end

      def method_missing name, *args, &blk
        raise unless args.empty?
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
