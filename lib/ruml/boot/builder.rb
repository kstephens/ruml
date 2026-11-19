# frozen_string_literal: true

require 'ruml/boot'
require 'ruml/core/runtime'
require 'ruml/compiler'
require 'ruml/support/navigable'
require 'ruml/support/basic_object'
require 'ruml/compiler/ast'
require 'ruml/compiler/target/ruby'
require 'ruml/support/logging'
require 'ruml/support/context'
require 'ruml/core/notation'
require 'ruml/compiler/frontend'
require 'binding_of_caller'

module RUML::Boot
  class Builder
    class Node < RUML::Support::BasicObject::Base
      def _desc_
        @_repr.inspect
      end
    end
    Notation = RUML::Core::Notation

    def initialize target
      @target = target
      @state = :active
      @items = []
      @pass = 0
    end

    def begin!
      this = self
      ::Module.define_method(:ruml) { this }
      self
    end

    def end!
      @state = :end
      ::Module.undef_method(:ruml)
      [1, 2].each do | pass|
        @items.each do | item |
          # $stderr.puts "#{self.class} : pass #{pass} #{item.inspect}"
          send(:"_#{item.name}_#{pass}", item)
        end
      end
      self
    end

    # def new name, props
    #   if @pass == 0
    #     Node.new(props)
    #   else
    #     @target.const_get(:UML).const_get(name).new(props)
    #   end
    # end

    def _property_1 item
      item.node = prop = Node.new({type: :Property})
      notation = item.args[0]
      prop.owner = item.target
      Notation.new.property(notation, prop) or raise
      gen = RUML::Compiler::Target::Ruby.new
      if item.blk
        item.target.define_method(prop.name, &item.blk)
        return
      end
      code = _wrap_code(item.target, gen.generate_property(prop, {}))
      _eval_code(code)
      # binding.pry
    end

    def _association_1 item
      props = item.args.map do | arg |
        prop = Node.new({type: :Property})
        Notation.new.property(arg, prop) or raise
        prop.type = _resolve_type(prop.type, item.target)
        prop.owner = _resolve_type(item.target, item.target)
        prop.ruby_module = _resolve_type(prop.type, item.target)
        prop
      end
      p1, p2 = props
      # binding.pry
      gen = RUML::Compiler::Target::Ruby.new
      result = gen.generate_association(p1, p2)
      result.each do | assoc |
        code = _wrap_code(assoc[:end1].ruby_module, assoc[:code])
        _eval_code(code)
      end
    end

    def _enum_1 item
      name = item.args[0].to_sym
      name_upper = name.to_s.upcase.to_sym
      item.target.singleton_class.include(Enumeration)
      item.target.define_singleton_method(name) { name }
      item.target.const_set(name_upper, name)
      self
    end

    def _property_2 item
    end

    def _association_2 item
    end

    def _enum_2 item
    end

    def _import item
      item.args.each do | ns |
        ns.constants do | c |
          target.const_set(ns.const_get(c))
        end
      end
    end

    def _resolve_type type, target
      return type if ::Module === type
      path = _split_path(type)
      target_path = _split_path(target)
      target = _lookup_path(target_path[0..-2], ::Kernel)
      target = ::Kernel if path[0] == ""
      _lookup_path(path, target)
    end
    def _split_path path
      path.to_s.split("::").reject(&:empty?)
    end
    def _lookup_path path, base
      path.inject(base) do | mod, name |
        mod.const_get(name) if name && name != ""
      end
    end

    def _wrap_code target, code
      prefix = case target
      when ::Class then "class"
      else "module"
      end
      "#{prefix} ::#{target} \n#{code} \nend # #{prefix} ::#{target} \n"
    end

    def _eval_code code, kind=""
      if @verbose
        lines = code.split("\n").select{|l| l =~ /^\s*(##RUML |module\s|class\s|def\s|alias\s)/}
        lines.unshift("# #{kind.to_s}")
        $stderr.puts(lines * "\n")
      end
      # if code =~ /\bnamespace=/
      #   puts(code)
      #   binding.pry
      # end
      ::Kernel.eval(code)
    end

    def method_missing name, *args, &blk
      return super(name, *args, &blk) unless @state == :active
      target = binding.of_caller(1).receiver
      target.include(Element)
      # binding.pry if blk
      @items << Item.new(target, name, args, blk)
      # $stderr.puts(@items[-1].inspect)
      self
    end

    class Item < Struct.new(:target, :name, :args, :blk, :node)
    end

    module Enumeration
      def _coerce_to_native(x)
        send(:"#{x.to_sym}")
      end
    end

    class EnumerationLiteral < Struct.new(:name)
      def to_s ; name.to_s ; end
      def to_sym ; name ; end
      def == other
        self == other || name == other.to_sym
      end
      alias_method :===, :==
    end

    module ModuleMethods
      def ruml *args, &blk
        # this = binding.of_caller(1).receiver
        (@@_ruml_ ||= Builder.new)._add(self, args, blk)
      end
      # ::Module.include(self)
    end

    module Element
      def initialize properties=nil
        properties&.each do | k, v |
          # binding.pry unless respond_to?(:"#{k}=")
          instance_variable_set(:"@#{k}", v)
          # send(:"#{k}=", v)
        end
      end
    end
  end
end

