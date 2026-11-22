# frozen_string_literal: true

require 'ruml/core'
require 'ruml/compiler/ast'
require 'ruml/support/misc'

module RUML::Compiler
    class Native
      include RUML::Support::Misc

      def initialize
        @cache = {}
        @lookup_module = {}
      end

      def lookup_module name
        return nil if name.nil?
        raise ArgumentError, "lookup_module : #{name.inspect}" unless ::String === name
        unless (mod = @lookup_module[name])
          mod = lookup_const(name)
          return nil unless ::Module === mod
          @lookup_module[name] = mod
        end
        # binding.pry unless mod
        mod
      end

      def build(x)
        case x
        when RElement then x
        when Class    then @cache[x] ||= prepare(RClass.new(x))
        when Module   then @cache[x] ||= prepare(RNamespace.new(x))
        when Method, UnboundMethod  then @cache[x] ||= prepare(ROperation.new(x))
        else x
        end
      end
      alias_method :[], :build

      def prepare(x)
        x.__ruml_native__ = self
        x.__initialize__
        x
      end

      class RElement < RUML::Compiler::AST::Node
        attr_accessor :__ruml_native__, :__ruml_obj__, :name, :owner, :ownedElement
        alias_method :namespace, :owner
        alias_method :namespace=, :owner=

        def __fail__ *args
          raise "#{args}"
        end

        def _desc_; @__ruml_obj__.inspect ; end

        def initialize obj
          @__ruml_obj__ = obj
          super({})
          # __initialize__
        end

        def ownedElement ; @ownedElement ||= [] ; end
        alias_method :ownedElement=, :__fail__
        def __initialize__ ; end
      end

      class RNamespace < RElement
        def to_s
          @__ruml_obj__.to_s
        end
        def __initialize__
          super()
          mod = @__ruml_obj__
          full_path = @__ruml_obj__.to_s
          name = ::RUML::Support::Misc.path_str_base(full_path)
          # binding.pry
          kind = ::Class === mod ? "class" : "module"
          declaration = "#{kind} #{name}"
          full_declaration = "#{kind} ::#{full_path}"
          self.name = name
          _.to_h.update(
            native: @__ruml_obj__,
            metatype: :Namespace,
            blk: nil,
            path: [full_path],
            path_str: full_path,
            ruby_module: mod,
            ruby_module_kind: kind,
            ruby_instance_behavior: name,
            ruby_module_behavior: name,
            ruby_declaration: declaration,
            ruby_declaration_full: full_declaration,
          )
        end

        def owner
          return @owner if defined?(@owner)
          @owner = nil
          path_str_parent = ::RUML::Support::Misc.path_str_parent(@__ruml_obj__)
          mod = @__ruml_native__.lookup_module(path_str_parent)
          # binding.pry unless mod
          @owner = @__ruml_native__[mod]
          @owner = nil unless path_str_parent
          @owner = nil if @owner == @__ruml_obj__
          self[:owner] = @owner
          # binding.pry unless @owner
          @owner
        end
        alias_method :namespace, :owner

        def ownedElement
          @__ruml_obj__
            .constants.map{|n| @__ruml_obj__.const_get(n)}
            .select{|v| ::Module === v}
            .map{|obj|
              node = @__ruml_native__[obj]
              node.owner = self
              node
            }.tap{|x| self[:ownedElement] = x}
        end
      end

      class RClass < RNamespace
        attr_accessor :ownedOperation

        def __initialize__
          super()
          _.metatype = :Class
          self.superClass = []
        end

        def ownedOperation
          @ownedOperation ||=
            @__ruml_obj__.instance_methods(false).map do | name |
              m = @__ruml_obj__.instance_method(name)
              node = @__ruml_native__[m]
              node.owner = self
              node
            end.tap{|x| self[:ownedOperation] = x}
        end
        alias_method :ownedOperation=, :__fail__
      end

      class ROperation < RElement
        def __initialize__
          super()
          self.name = @__ruml_obj__.name.to_s.dup.freeze
        end
        def owner
          @owner ||= @__ruml_native__[@__ruml_obj__.owner]
        end
        def parameter
          @parameter ||= begin
            id = 0
            @__ruml_obj__.parameters.map do | (_kind, name) |
              name ||= "_unmamed_#{id += 1}"
              # $stderr.puts(@__ruml_native__.inspect)
              node = @__ruml_native__.prepare(::RUML::Compiler::Native::RParameter.new(name, nil))
              node.owner = self
              node
            end
          end.sort_by(&:name)
        end
      end

      class RParameter < RElement
        def initialize name, type
          super(nil)
          self.name = name
          self.type = type
        end
      end
    end
end
