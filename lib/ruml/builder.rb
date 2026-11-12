# frozen_string_literal: true

require 'ruml'
require 'ruml/core/runtime'
require 'ruml/compiler'
require 'ruml/navigable'
require 'ruml/compiler/ast'
require 'ruml/logging'
require 'ruml/support/context'

module RUML

  # Understands a small DSL for UML modeled in subset of UML Substructure.
  class Builder
    include Logging
    attr_reader :created, :root, :contexts

    include Compiler::AST::Repr, Logging
    def _repr ; @contexts.node ; end

    def initialize opts = nil, &blk
      opts ||= { } # EMPTY_HASH
      @opts = opts
      @_log_verbose = true # @opts[:verbose]
      @created = [ ]
      @contexts = ::RUML::Contexts.new
      @root = @opts[:root] || _build(:root, [])
      @root.ownedElement = []
      @node_for_module = {}
      if block_given?
        _with(@root) do
          _with(@root, :namespace) do
            @result = instance_eval(&blk)
          end
        end
      end
    end

    def self.collector *names, &blk
      source_location = [__FILE__, __LINE__ - 1]
      names.each do |meta|
        meta = meta.to_sym
        raise "collector : #{meta} : unexpected block" if blk
        expr = <<"RUBY"
def #{meta} *args, &blk
  _build(:#{meta}, args, blk)
end
RUBY
        class_eval(expr, *source_location)
      end
    end

    collector :import, :stereotype, :association, :constant

    # Include a native Ruby Module into a MOF namespace:
    def include *modules
      (@contexts.namespace._.ruby_include ||= []).concat(modules).uniq!
    end
    def extend *modules
      (@contexts.namespace._.ruby_extend ||= []).concat(modules).uniq!
    end

    def package *args, &blk
      # binding.pry
      _build(:package, args) do | node |
        _namespace(node,&blk)
      end
    end

    def class_ *args, &blk
      namespace = @contexts.namespace
      _build(:class, args) do | node |
        node.namespace = namespace
        node.ownedElement = []
        node.superClass = [] # : Class[*] #
        supers = args[1..-1]
        supers.map(&:to_s).each do | name |
          node.superClass << (node.namespace._.find(name) or name)
        end
        _with(node, :classifier) do
          node.isAbstract = false
          node.ownedAttribute = []
          node.ownedOperation = []
          node.generalization = []
          _namespace(node, &blk)
        end
      end
    end

    def superClass *names
      class_ = @contexts.class
      names.each do | name |
        superClass = class_.namespace._.find(name.to_s)
        cls.superClass << superClass
      end
      # binding.pry
    end

    def generalization *args
      specific = @contexts.classifier
      args.each do | name |
        name = name.to_s
        gen = _build(:generalization, [])
        general = specific.namespace._.find(name)
        # if general is not found, yet, just store the name:
        gen.general = general || name
        gen.specific = specific
        specific.generalization << gen
        general.generalization << gen if general
        # binding.pry
      end
    end

    def property *args
      _build(:property, args) do | node |
        node.namespace = _current(:namespace)
        node.namespace.ownedElement << node
        node.type = nil # UNTYPED
        node.multiplicity = 1
        node.aggregation = :none # : AggregationKind = none
        node.default = []  # : String [0..]
        node.isComposite = false # : Boolean
        node.isDerived = false # : Boolean = false
        node._.args_named(args, :name, :type, :multiplicity)
        node.association = []
        node.owningAssociation = []
        node.opposite = []
        node.class = _current(:class)
        node.class.ownedAttribute << node
        node.type = _type_to_node(node.type)
        # binding.pry
      end
    end

    def operation *args, &blk
      _build(:operation, args) do | node |
        node.namespace = _current(:namespace)
        node.namespace.ownedElement << node
        node._.blk = blk
        node.class = _current(:class)
        node.class.ownedOperation << node
        # ??? node.owner = node.class
        node.parameter = []
        _namespace(node) do
          node.parameter = blk.parameters.map do |(_kind, name)|
            param = _build(:parameter, [name, nil])
            param.operation = node
            param.name = name
            param.type = nil # Ruby parameters are untyped
            # ParameterDirectionKind
            param.direction = :in
          end
          param = _build(:parameter, ["return", nil])
          param.operation = node
          param.name = "return"
          param.type = nil # Ruby parameters are untyped
          param.direction = :return
        end
      end
    end
    alias_method :method, :operation

    def _namespace node, &blk
      node.namespace = _current(:namespace)
      (node.namespace.ownedElement ||= []) << node
      node.owner = node.namespace
      _with(node, :namespace, &blk)
    end

    #####################################

    def _build meta, args, opts=nil, blk=nil
      meta = meta.to_sym
      _args = args.dup
      blk ||= _args.pop if ::Proc === _args[-1]
      opts ||= _args.pop if ::Hash === _args[-1]
      name = _name(_args[0])
      node = ::RUML::Compiler::AST::Node[
        name: name,
        stereotype: [],
      ]
      node_parent = _current(:node)
      node_parent._.node_children << node if node_parent
      node._.to_h.update(
        meta: meta,
        type_name: meta.to_s.capitalize,
        name: name,
        args: args,
        opts: opts&.dup || {},
        blk: blk,
        node_parent: node_parent,
        node_children: [],
        ruby_native: false,
        ruby_include: [],
        ruby_extend: [],
        ruby_module: nil,
      )
      @created << node
      if block_given?
        @contexts.node(node) do
          @contexts[meta].with(node) do
            yield node
          end
        end
      end
      node
    end

    def _type_to_node x
      case type
      when nil, Compiler::AST::Node, Symbol, String
        x
      when ::Class
        @node_for_module[x] ||= begin
          full_path_str = x.to_s
          name = full_path_str.split("::")[-1]
          _build(:class, [name]) do | node |
            node.ownedElement = []
            node._._repr.update(
              parent: nil,
              ruby_native: true,
              ruby_module: x,
              ruby_module_instance: x,
              ruby_module_module: x.class,
              node_path_str: full_path_str,
              full_path_str: full_path_str,
            )
          end
        end
      else
        raise "_to_class"
      end
    end

    def _name arg
      case arg
      when ::String, ::Symbol then arg.to_s
      when Compiler::AST::Node then arg.name
      end
    end

    def _desc node
      path_str = node._.namespace_str
      "#{self.class} #{node.inspect} @ #{path_str}"
    end

    def _current(name)
      @contexts[name].current
    end

    def _with(node, name=nil, &blk)
      name ||= node._.meta
      context = @contexts[name]
      # $stderr.puts("#{'  ' * context.depth} #{name} | #{node.inspect}}")
      context.with(node, &blk)
    end

    def _compile(opts = { })
      opts = @opts.merge(opts)
      c = Compiler::Compiler.new(opts)
      # binding.pry
      c.run(@root)
      c
    end

    #####################################

    def inspect detail=false
      return super() if detail
      "#<#{self.class} ...>"
    end
  end
end
