# frozen_string_literal: true

require 'ruml/boot'
require 'ruml/core/runtime'
require 'ruml/support/basic_object'
require 'ruml/compiler/target/ruby'
require 'ruml/core/notation'
require 'binding_of_caller'

module RUML::Boot
  class Builder
    BasicObject = ::RUML::Support::BasicObject
    Enumeration = ::RUML::Core::Runtime::Enumeration
    NotationError = ::RUML::Core::NotationError
    Error = ::RUML::Error

    class Node < BasicObject::Base
      def _desc_
        @_repr.inspect
      end
      def _ ; @_ ||= BasicObject::Base.new ; end
    end
    Notation = RUML::Core::Notation

    def initialize root
      @root = root
      @state = :active
      @items = []
      @pass = 0
      @target = RUML::Compiler::Target::Ruby.new
      @info = Hash.new {|h, k| h[k] = BasicObject::Base.new({})}
      @notation = Notation.new(self)
    end

    def info obj
      @info[obj]
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
      File.write("tmp/builder.rb", @target.to_s)
      load("tmp/builder.rb")
      # ::Kernel.eval(@target.to_s)
      self
    end

    def _property_1 item
      raise NotationError, "Property : expected 1 args" if items.args.size != 1
      notation = item.args[0]
      item.node = prop = @notation.property(notation) or raise NotationError, "Property : #{notation.inspect}"
      prop.owner = item.target
      prop.name = _fix_name(prop.name)
      gen = RUML::Compiler::Target::Ruby.new
      if item.blk
        item.target.define_method(prop.name, &item.blk)
        return
      end
      code = _wrap_code(item.target, gen.generate_property(prop, {}))
      @target << code
      # _eval_code(code)
      # binding.pry
    end
    def _property_2 item
    end

    def _association_1 item
      raise NotationError, "Association : expected 2 args" if items.args.size != 2
      props = item.args.map do | notation |
        prop = @notation.property(notation) or
          raise NotationError, "Association : #{notation.inspect}"
        prop.name = _fix_name(prop.name)
        prop.type = _resolve_type(prop.type, item.target)
        prop.owner = _resolve_type(item.target, item.target)
        info(prop).ruby_module = _resolve_type(prop.type, item.target)
        prop
      end
      p1, p2 = props
      # binding.pry
      gen = RUML::Compiler::Target::Ruby.new
      result = gen.generate_association(p1, p2)
      result.each do | assoc |
        prop = assoc[:end1]
        code = _wrap_code(info(prop).ruby_module, assoc[:code])
        @target << code
      end
    end
    def _association_2 item
    end

    def _operation_1 item
      raise NotationError, "Operation : expected 1 args" if items.args.size != 1
      op = @notation.operation(item.args[0]) or
        raise NotationError, "invalid Operation : #{notation.inspect}"
      op.name = _fix_name(op.name)
      op.type = _resolve_type(op.type, item.target)
      info(op).ruby_module = _resolve_type(op.type, item.target)
      op.parameters.map! do | param |
        param
      end
    end

    def _operation_2 item
    end

    def _enum_1 item
      unless info(item.target).isEnumeration
        info(item.target).isEnumeration = true
        @items << Item.new(item.target, :enumeration, item.target.to_s)
      end
      (info(item.target).enumerations ||= []) << item
    end
    def _enum_2 item
    end

    def _enumeration_1 item
    end

    def _enumeration_2 item
      enumerations = info(item.target).enumerations
      names = enumerations.map{|enum| enum.args[0].to_s}
      code = <<"RUBY"
  include(::#{Enumeration})
  def self.names
    @names ||= #{names.inspect}.freeze
  end
RUBY
      @target << _wrap_code(item.target, code)
    end

    def _import_1 item
      item.args.each do | ns |
        ns.constants do | c |
          item.target.const_set(ns.const_get(c))
        end
      end
    end
    def _import_2 item
    end

    def _resolve_type type, target
      return nil if type.nil?
      return type if ::Module === type
      path = _split_path(type)
      binding.pry if path.empty?
      target_path = _split_path(target)
      target = _lookup_path(target_path[0..-2], ::Kernel)
      target = ::Kernel if path[0] == ""
      _lookup_path(path, target)
    end

    def _split_path path
      path.to_s.split("::")
    end

    def _lookup path, base
      path = _split_path(path, base)
      binding.pry if path.empty?
      base = [ @root ] if path[0] == ""
      while base
        if (ns = _lookup_path(path, base))
          return ns
        end
        base = base.pop
      end
    end

    def _lookup_path path, base
      path.inject(base) do | mod, name |
        if name && name != ""
          name = name.to_sym
          begin
            mod.const_get(name, false)
          rescue ::NameError
            return nil
          end
        end
      end
    end

    def _fix_name name
      RUBY_KEYWORDS.include?(name) ? "#{name}_" : name
    end

    def new ns, name, props, id = nil
      obj = Node.new(props)
      obj._.metatype = name.to_sym
      obj
    end

    RUBY_KEYWORDS = %w[
      class module
      begin end
      if else elsif
      case then else
      raise rescue ensure
      catch throw
    ]

    def _wrap_code target, code
      prefix = case target
      when ::Class then "class"
      when ::Module then "module"
      else raise Error, "invalid target : #{target.inspect}"
      end
      "\n#{prefix} ::#{target} \n#{code} \nend # #{prefix} ::#{target} \n\n"
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
