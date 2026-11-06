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
        @id_to_object = {}
      end

      def make_instance(namespace, name, properties, id=nil)
        if id and other = @id_to_object[id]
          puts "found #{id} : #{other}"
          return other
        end

        cls = get_xmi_type(namespace, name)
        obj = cls.new
        obj._xmi.type = "#{namespace}:#{name}"
        properties.each do | name, value |
          obj.__send__(:"#{name}=", value)
        end
        obj._xmi.object_id = (@object_id += 1)
        if id
          if other = @id_to_object[id]
            raise ArgumentError, "object with id #{id.inspect} already exists : #{other}"
          end
          @id_to_object[id] = obj
          puts "created #{id} : #{other}"
        end
        obj
      end

      def get_xmi_namespace(xmlns)
        xmlns = xmlns.to_sym
        @namespaces[xmlns] ||= Namespaces.const_get(:"N_#{xmlns}", false)
      end

      def get_xmi_type(xmlns, name)
        xmlns = xmlns.to_sym
        name_sym = name.to_sym
        mod = get_xmi_namespace(xmlns)
        return mod.const_get(name_sym, false) if mod.const_defined?(name_sym, false)
        cls = ::Class.new(Base)
        cls.extend(BaseAttributes)
        cls.extend(Metaclass)
        cls._xmi_initialize_BaseAttributes
        cls._xmi.xmlns = xmlns
        cls._xmi.name = name_sym
        mod.const_set(name_sym, cls)
        cls
      end
    end

    module Metaclass
    end

    # These are directly related to XML namespace tags.
    # See get_xmi_namespace()
    module Namespaces
      module N_xmi; end
      module N_uml; end
      module N_mof; end
      module N_mofext; end
    end

    # Generic attributes for all objects.
    class Attributes
      attr_reader :properties, :associations
      attr_accessor :object_id, :id
      attr_accessor :xmlns, :name
      attr_accessor :type, :type_prefix, :type_name
      attr_accessor :package, :namespace, :_class
      attr_accessor :module, :module_name, :modules
      attr_accessor :imports
      attr_accessor :url, :line
      @@object_id = 0

      def initialize
        @properties = {}
        @associations = ::Hash.new{|h, k| h[k] = []}
        @operations = {}
        @modules = {}
        @imports = []
        @object_id = (@@object_id += 1)
      end
    end

    # Mixin that provides basic Property and Association support.
    module BaseAttributes
      attr_reader :_xmi

      def _xmi_initialize_BaseAttributes
        @_xmi = Attributes.new
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
          if @_xmi.associations.key?(sel)
            @_xmi.associations[sel]
          else
            @_xmi_properties[sel]
          end
        when (name = sel.to_s) && name[-1] == "=" && args.size == 1
          name = name[0..-2].to_sym
          if @_xmi.associations.key?(name)
            @_xmi.associations[name] = [ args[0] ]
          else
            @_xmi.properties[name] = args[0]
          end
        else
          # $stderr.puts "sel=#{sel.inspect} args=#{args.inspect}"
          @_xmi.operations[sel].call(*args)
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
        id = "#{__id__}:#{@_xmi.object_id.inspect}"
        "#<#{cls&.name} #{id} #{@_xmi_properties.inspect}>"
      end

      def to_s
        return inspect
        cls = _xmi_class
        id = "#{__id__}:#{@_xmi.object_id.inspect}"
        "#<#{cls&.name} #{id} />"
      end
    end
  end
end
