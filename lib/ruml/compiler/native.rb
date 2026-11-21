# frozen_string_literal: true

require 'ruml/core'
require 'ruml/compiler/ast'

module RUML::Compiler
    class Native
      def initialize
        @cache = {}
      end

      def lookup_module name
        name.split("::", -1).inject(::Object) do | mod, name |
          return unless ::Module === mod
          begin
            mod.const_get(name, false)
          rescue NameError
            return nil
          end
        end
      end

      def parent_name x
        x.to_s.split("::", -1)[1..-2].join("::")
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
        x
      end

      class RElement < RUML::Compiler::AST::Node
        attr_accessor :__ruml_native__, :__ruml_obj__, :owner, :ownedElement
        alias_method :namespace, :owner
        alias_method :namespace=, :owner=

        def _desc_; @__ruml_obj__.inspect ; end

        def initialize obj
          @__ruml_obj__ = obj
          super({})
        end

        def ownedElement ; @ownedElement ||= [].freeze ; end
        def __initialize__ ; end
      end

      class RNamespace < RElement
        def __initialize__
          mod = @__ruml_obj__
          full_path = @__ruml_obj__.to_s
          name = full_path.sub(/^.*::/, '')
          kind = ::Class === mod ? "class" : "module"
          declaration = "#{kind} #{name}"
          full_declaration = "#{kind} ::#{full_path}"
          self.name = name
          _.to_h.update(
            meta: :Namespace,
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

        def name
          @name ||= @__ruml_obj__.to_s.sub(/^.+::/, '').freeze
        end

        def owner
          return @owner if defined?(@owner)
          @owner = nil
          parent_name = @__ruml_native__.parent_name(@__ruml_obj__)
          mod = @__ruml_native__.lookup_module(parent_name)
          @owner = @__ruml_native__[mod]
          @owner = nil if parent_name == ""
          @owner = nil if @owner == @__ruml_obj__
          @owner
        end
        alias_method :namespace, :owner

        def ownedElement
          @ownedElement ||= @__ruml_obj__
            .constants.map{|n| @__ruml_obj__.const_get(n)}
            .select{|v| ::Module === v}
            .map{|obj|
              node = @__ruml_native__[obj]
              node.owner = self
              node
            }.freeze
        end
      end

      class RClass < RNamespace
        attr_accessor :ownedOperation

        def __initialize__
          super()
          _.meta = :Class
        end

        def ownedOperation
          @ownedOperation ||=
            @__ruml_obj__.instance_methods(false).map do | name |
              m = @__ruml_obj__.instance_method(name)
              node = @__ruml_native__[m]
              node.owner = self
              node
            end.freeze
        end
      end

      class ROperation < RElement
        def owner
          @owner ||= @__ruml_native__[@__ruml_obj__.owner]
        end
        def name
          @name ||= @__ruml_obj__.name.to_s.dup.freeze
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
          end.sort_by(&:name).freeze
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
