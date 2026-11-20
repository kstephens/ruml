# frozen_string_literal: true

require 'ruml/boot'
require 'ruml/core/runtime'
require 'ruml/core/notation'
require 'ruml/compiler/target/ruby'
require 'ruml/support/basic_object'
require 'ruml/support/context'
require 'binding_of_caller'

module RUML::Boot
  class Builder
    BasicObject = ::RUML::Support::BasicObject
    Enumeration = ::RUML::Core::Runtime::Enumeration
    NotationError = ::RUML::Core::NotationError
    Error = ::RUML::Error

    class Node < BasicObject::Base
      def _desc_ ; @_repr.inspect ; end
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
      @trace = false
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
      [0, 1, 2].each do | pass|
        @items.each do | item |
          sel = :"_#{item.name}_#{pass}"
          if respond_to?(sel)
            $stderr.puts "#{self.class} : pass #{pass} #{item.inspect}" if @trace
            send(sel, item)
          end
        end
      end
      File.write("tmp/builder.rb", @target.to_s)
      load("tmp/builder.rb")
      # ::Kernel.eval(@target.to_s)
      self
    end

    ##########################################

    def _import_0 item
      item.args.each do | ns |
        src = _resolve_value(ns, item.target)
        dst = item.target
        $stderr.puts("### import #{ns} -> #{src.inspect}") if @trace
        raise "import : cannot find #{ns.inspect} in #{dst.inspect}" unless ns
        src.constants.each do | c |
          $stderr.puts("### import #{dst}::#{c} = #{src}::#{c}") if @trace
          dst.send(:remove_const, c) rescue nil
          dst.const_set(c, src.const_get(c))
        end
      end
    end

    def _property_1 item
      raise NotationError, "Property : expected 1 args" if item.args.size != 1
      notation = item.args[0]
      prop = @notation.property(notation)
      raise NotationError, "Property : #{notation.inspect}" unless prop
      item.node = prop
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

    def _association_1 item
      raise NotationError, "Association : expected 2 args" if item.args.size != 2
      props = item.args.map do | notation |
        prop = @notation.property(notation)
        raise NotationError, "Association : #{notation.inspect}" unless prop
        prop.name = _fix_name(prop.name)
        type = _resolve_type(prop.type, item.target)
        raise NotationError, "Association : #{notation.inspect} : cannot resolve type #{prop.type.inspect}" unless type
        prop.owner = _resolve_type(item.target, item.target)
        prop.type = type
        prop._.ruby_module = prop.type
        prop
      end
      p1, p2 = props
      gen = RUML::Compiler::Target::Ruby.new
      result = gen.generate_association(p1, p2)
      result.each do | assoc |
        prop = assoc[:end1]
        code = _wrap_code(prop._.ruby_module, assoc[:code])
        @target << code
      end
    end

    def _operation_1 item
      raise NotationError, "Operation : expected 1 args" if item.args.size != 1
      notation = item.args[0]
      item.node = op = @notation.operation(notation)
      raise NotationError, "Operation : #{notation.inspect}" unless op
      op.name = _fix_name(op.name)
      op._.ruby_module = item.target
      op.parameters.each do | param |
        param.name = _fix_name(param.name)
        pp(param.to_h) if @trace
        type = _resolve_type(param.type, item.target)
        raise NotationError, "Parameter : #{param.name.inspect} : cannot resolve type #{param.type.inspect}" unless type
        param.type = type
      end
    end

    def _enum_1 item
      unless info(item.target).isEnumeration
        info(item.target).isEnumeration = true
        @items << Item.new(item.target, :enumeration, item.target.to_s)
      end
      (info(item.target).enumerations ||= []) << item
    end

    def _enumeration_2 item
      enumerations = info(item.target).enumerations
      names = enumerations.map{|enum| enum.args[0].to_s}
      code = <<"RUBY"
  include(::#{Enumeration})
  def self.names
    @names ||= #{names.inspect}.map!(&:freeze).freeze
  end
RUBY
      @target << _wrap_code(item.target, code)
    end

    ##########################################

    def _resolve_type type, base
      _resolve_value(type, base)
    end

    def _resolve_value name, base
      return name if name.nil? || ::Module === name
      type_path = _split_path(name)
      base_path = _split_path(base)[0..-2]
      _lookup_in_scope(type_path, base_path, ::Object)
    end

    def _split_path path
      return path if ::Array === path
      path.to_s.strip.split("::", -1).map!(&:strip).map!(&:freeze).reject(&:empty?)
    end

    def _lookup_in_scope path, base_path, root=nil
      base_path = base_path.dup
      base_path = [ root || @root ] if base_path.empty? || base_path[0] == ""
      # pp(_lookup_in_scope: [path, base_path]) if @trace
      until base_path.empty?
        base_obj = _lookup_value(base_path, ::Object)
        if (ns = _lookup_value(path, base_obj))
          return ns
        end
        base_path.pop
      end
    end

    def _lookup_value path, base_module
      path.inject(base_module) do | mod, name |
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
      # $stderr.puts(@items[-1].inspect) if @trace
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
          instance_variable_set(:"@#{k}", v)
          # send(:"#{k}=", v)
        end
      end
    end
  end
end
