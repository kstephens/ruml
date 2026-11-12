# frozen_string_literal: true

require 'rmof'
require 'logger'
require 'ruml/support/logging'

module RMOF
  module Boolean; end
  ::FalseClass.extend(Boolean)
  ::TrueClass.extend(Boolean)
end

module RUML
  module XMI
    class Factory
      include RUML::Support::Logging::Basic

      attr_reader :root, :classes, :objects

      def initialize
        @namespaces = {}
        @object_id = 0
        @id_to_object = {}
        @object_id_to_object = {}
        @to_class = {}
        @classes = []
        @objects = []
        @get_class = {}
        @root = Module.new
        logger.level = Logger::WARN
      end

      def make_instance(xmlns, name, properties=nil, id=nil)
        if id and obj = @id_to_object[id]
          logger.debug "make_instance(#{xmlns.inspect} #{name.inspect}) : found #{id} : #{obj}"
          return obj
        end
        cls = get_class(xmlns, name)
        obj = cls.new
        register_object(obj)
        obj._xmi.metatype = cls._xmi
        properties&.each do | name, value |
          obj.__send__(:"#{name}=", value)
        end
        @id_to_object[id] = obj if id
        @objects << obj
        logger.info "make_instance : #{xmlns.inspect} : #{name.inspect} : #{properties.inspect} : #{id.inspect} => #{cls} @ #{obj._xmi.object_id}"
        obj
      end

      def get_class(xmlns, name, properties=nil, id=nil)
        key = [xmlns, name]
        if cls = @get_class[key]
          return cls
        end
        xmlns = xmlns.to_sym
        name_sym = name.to_sym
        mod = get_module(xmlns)
        return mod.const_get(name_sym, false) if mod.const_defined?(name_sym, false)
        cls = ::Class.new(Instance)
        cls.extend(ClassAttributes)
        register_object(cls)
        cls._xmi.xmlns = xmlns
        cls._xmi.name = name_sym
        cls._xmi.ident = "#{xmlns}:#{name}"
        mod.const_set(name_sym, cls)
        @classes << cls
        @get_class[key] = cls
        # @classes.sort_by!(&:ident)
        logger.info "get_class(#{xmlns.inspect}, #{name.inspect}) -> #{cls}"
        cls
      end

      def get_module(xmlns)
        xmlns = xmlns.to_sym
        @namespaces[xmlns] ||= Module.new.tap{|m| @root.const_set(:"N_#{xmlns}", m)}
      end

      def register_object obj
        obj._xmi.object_id = (@object_id += 1)
        @object_id_to_object[obj._xmi.object_id] = obj
        obj
      end

      def associate(memberEnd1, name, memberEnd2)
        outgoing = memberEnd1._xmi.associations[name]
        raise unless memberEnd2
        outgoing.push(memberEnd2).uniq!(&:__id__) if memberEnd2
        logger.debug { "  associations: #{memberEnd1._xmi.associations.keys.inspect}" }
      end

      def get_object(search)
        case search
        when Integer
          @object_id_to_object[search]
        when Regexp, String
          @object_id_to_object.values.select do | obj |
            meta = obj._
            search === meta.ident or
            search === meta.type or
            search === meta.name or
            meta.properties.keys.map(&:to_s).any?{|x| search === x } or
            meta.properties.values.map(&:to_s).any?{|x| search === x} or
            false
          end
        end
      end

      def set_source_location(obj, *args)
        obj._.source_location = SourceLocation.new(*args)
      end
    end

    SourceLocation = Struct.new(:uri, :line, :column)

    # Mixin that provides basic Property and Association support.
    module BaseAttributes
      def _xmi ; @_xmi ||= Attributes.new(self) ; end
      alias_method :_, :_xmi
      def method_missing sel, *args, &blk
        _xmi.do_method_missing(sel, args, blk)
      end
    end
    module ClassAttributes
      include BaseAttributes
      def inspect ; _xmi.inspect_class ; end
    end
    class Instance < ::BasicObject
      include BaseAttributes
      def inspect ; _xmi.inspect_object ; end
    end

    def self.copy_method(dst,dst_name, src_module, src_name = dst_name)
      dst.define_method(dst_name, src_module.instance_method(src_name))
    end
    copy_method(Instance, :__class__, ::Kernel, :class)
    copy_method(Instance, :__caller_locations__, ::Kernel, :caller_locations)
    copy_method(Instance, :__raise__, ::Kernel, :raise)

    # Generic attributes for all objects.
    class Attributes
      attr_reader :properties, :associations
      attr_accessor :object_id, :id
      attr_accessor :xmlns, :name, :ident
      attr_accessor :source_location
      attr_accessor :type, :type_prefix, :type_name, :metatype
      attr_accessor :package, :namespace, :class_
      attr_accessor :module, :module_name, :modules
      attr_accessor :imports

      def initialize obj
        @obj = obj
        @properties = {}
        @associations = ::Hash.new{|h, k| h[k] = []}
        @operations = {}
        @modules = {}
        @imports = []
        @object_id = 0
      end

      def keys
        @properties.keys + @associations.keys + @operations.keys
      end

      def do_method_missing sel, args, blk
        case
        when blk
          raise ::StandardError, "#{sel}: block given"
        when args.empty?
          if @associations.key?(sel)
            @associations[sel]
          else
            @properties[sel]
          end
        when (name = sel.to_s) && name[-1] == "=" && args.size == 1
          name = name[0..-2].to_sym
          if @associations.key?(name)
            @associations[name] = [ args[0] ]
          else
            @properties[name] = args[0]
          end
        else
          @operations[sel].call(*args)
        end
      end

      def kind_name
        @ident || @metatype&.ident
      end

      def inspect_object
        "#<RUML::Object #{@metatype.ident} #{@object_id} #{@properties.inspect}>"
      end

      def inspect_class
        "#<RUML:Class #{@ident} #{@object_id} #{@properties.inspect}>"
      end
    end

  end
end
