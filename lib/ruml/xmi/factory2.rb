# frozen_string_literal: true

require 'ruml'
require 'logger'
require 'ruml/support/logging'
require 'ruml/compiler/ast'

module RMOF
  module Boolean; end
  ::FalseClass.extend(Boolean)
  ::TrueClass.extend(Boolean)
end

module RUML
  module XMI
    class Factory2
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
        self.log_verbose = false
        logger.level = Logger::INFO
      end

      def make_instance(xmlns, xmi_type_name, properties, unique_id=nil)
        # xmi_type_prefix, xmi_type_name, properties, unique_id
        if unique_id and (obj = @id_to_object[unique_id])
          log { "make_instance(#{xmlns.inspect} #{xmi_type_name.inspect}) : found #{unique_id} : #{obj}" }
          return obj
        end
        properties = properties.transform_keys(&:to_sym)
        obj = RUML::Compiler::AST::Node.new(properties)
        name = properties[:name]
        obj._.to_h.update(
          name: name,
          xmlns: xmlns,
          xmi_type_name: xmi_type_name,
          type_name: xmi_type_name,
          ident: "?ident?",
          unique_id: unique_id,
          node_parent: nil,
          node_children: [],
          properties: properties.keys,
          associations: [],
        )
        @id_to_object[unique_id] = obj if unique_id
        register_object(obj)
        log { "make_instance : #{xmlns.inspect} : #{xmi_type_name.inspect} : #{properties.inspect} : #{unique_id.inspect} => #{obj._.object_id}" }
        # binding.pry
        obj
      end

      def register_object obj
        obj._.object_id = (@object_id += 1)
        @object_id_to_object[obj._.object_id] = obj
        @objects << obj
        obj
      end

      def associate(memberEnd1, name, memberEnd2)
        unless (outgoing = memberEnd1[name])
          outgoing = memberEnd1[name] = []
          memberEnd1._.associations ||= []
          (memberEnd1._.associations << name).uniq!
        end
        outgoing.push(memberEnd2).uniq!(&:__id__)
        log { "  associations: #{memberEnd1._.associations.inspect}" }
      end
6
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
      def _ ; @_ ||= Attributes.new(self) ; end
      def method_missing sel, *args, &blk
        _.do_method_missing(sel, args, blk)
      end
    end
    module ClassAttributes
      include BaseAttributes
      def inspect ; _.inspect_class ; end
    end
    class Instance < ::BasicObject
      include BaseAttributes
      def inspect ; _.inspect_object ; end
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
