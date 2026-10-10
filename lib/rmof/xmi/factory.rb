# frozen_string_literal: true
require 'rmof'

module RMOF
  module Boolean; end
  ::FalseClass.extend(Boolean)
  ::TrueClass.extend(Boolean)

  module XMI
    class Factory
      def initialize
        @namespaces = {}
        @object_id = 0
      end

      def make_instance(namespace, name, properties)
        cls = get_xmi_type(namespace, name)
        obj = cls.new
        obj._xmi_type = "#{namespace}:#{name}"
        properties.each do | name, value |
          obj.__send__(:"#{name}=", value)
        end
        obj._xmi_object_id = (@object_id += 1)
        obj
      end

      def get_xmi_namespace(name)
        if result = @namespaces[name]
          result
        end
        @namespaces[name] = Namespaces.const_get(:"N_#{name}", false)
      end

      def get_xmi_type(ns, name)
        ns = ns.to_sym
        name_sym = name.to_sym
        mod = get_xmi_namespace(ns)
        return mod.const_get(name_sym, false) if mod.const_defined?(name_sym, false)
        cls = ::Class.new(Base)
        cls.extend(BaseAttributes)
        mod.const_set(name_sym, cls)
        cls._xmi_initialize_BaseAttributes
        cls
      end

    end

    module Namespaces
      module N_xmi; end
      module N_uml; end
      module N_mof; end
      module N_mofext; end
    end

    module BaseAttributes
      attr_reader :_xmi_properties, :_xmi_associations
      attr_accessor :_xmi_object_id, :_xmi_id
      attr_accessor :_xmi_type, :_xmi_type_prefix, :_xmi_type_name
      attr_accessor :_xmi_package, :_xmi_namespace
      attr_accessor :_xmi_module, :_xmi_module_name, :_xmi_modules
      attr_accessor :_xmi_imports
      @@_xmi_object_id = 0

      def _xmi_initialize_BaseAttributes
        @_xmi_properties = {}
        @_xmi_associations = ::Hash.new{|h, k| h[k] = []}
        @_xmi_operations = {}
        @_xmi_modules = {}
        @_xmi_imports = []
        # @_xmi_object_id = (@@_xmi_object_id += 1)
      end

      def _xmi_class
        # BasicObject does not have a #class method.
        (class << self; self; end).superclass
      end

      def method_missing sel, *args, &blk
        case
        when blk
          raise ::StandardError, "#{sel}: block given"
        when args.empty?
          if @_xmi_associations.key?(sel)
            @_xmi_associations[sel]
          else
            @_xmi_properties[sel]
          end
        when (name = sel.to_s) && name[-1] == "=" && args.size == 1
          name = name[0..-2].to_sym
          if @_xmi_associations.key?(name)
            @_xmi_associations[name] = [ args[0] ]
          else
            @_xmi_properties[name] = args[0]
          end
        else
          # $stderr.puts "sel=#{sel.inspect} args=#{args.inspect}"
          @_xmi_operations[sel].call(*args)
        end
      end
    end

    class Base < ::BasicObject
      include BaseAttributes

      def initialize
        _xmi_initialize_BaseAttributes
      end

      def inspect
        cls = _xmi_class
        id = "#{__id__}:#{@_xmi_object_id.inspect}"
        "#<#{cls&.name} #{id} #{@_xmi_properties.inspect}>"
      end

      def to_s
        cls = _xmi_class
        id = "#{__id__}:#{@_xmi_object_id.inspect}"
        "#<#{cls&.name} #{id} />"
      end
    end
  end
end

