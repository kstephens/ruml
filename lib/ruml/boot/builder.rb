# frozen_string_literal: true

require 'ruml'
require 'ruml/core/runtime'
require 'ruml/compiler'
require 'ruml/core/navigation'
require 'ruml/core/notation'
require 'ruml/core/misc'
require 'ruml/boot/factory'
require 'ruml/support/navigable'
require 'ruml/support/basic_object'
require 'ruml/compiler/ast'
require 'ruml/compiler/native'
require 'ruml/support/logging'
require 'ruml/support/context'
require 'ruml/compiler/frontend'

module RUML

  # Understands a small DSL for UML modeled in subset of UML Substructure.
  class Boot::Builder
    include Support::Logging
    attr_reader :created, :root, :contexts, :navigator
    Misc = ::RUML::Support::Misc
    UniqueArray = ::RUML::Core::Misc::UniqueArray
    include Support::BasicObject::Repr, Support::Logging
    def _repr ; @contexts.node ; end

    def initialize opts = nil, &blk
      @factory = RUML::Boot::Factory.new
      @notation = RUML::Core::Notation.new(@factory)
      @contexts = ::RUML::Support::Contexts.new
      @navigator = RUML::Core::Navigation::Navigator.new
      opts ||= { } # EMPTY_HASH
      @opts = opts
      @_log_verbose = true # @opts[:verbose]
      @created = [ ]
      @root = @opts[:root] || _build(:RUML, :Root, {})
      @root.ownedElement = UniqueArray.new
      @native = RUML::Compiler::Native.new
      @stereotypes = {}
      @object_id = 0
      @module_proxy = {}
      _start(&blk) if block_given?
      self
    end

    def _start &blk
      _with(@root, :Root) do
        _with(@root, :Namespace) do
          @result = instance_eval(&blk)
        end
      end
    end

    # Include a native Ruby Module into a MOF namespace:
    def include *modules
      (_current(:Namespace)._.ruby_include ||= UniqueArray.new).concat(modules)
    end
    def extend *modules
      (_current(:Namespace)._.ruby_extend ||= UniqueArray.new).concat(modules)
    end

    def package name, &blk
      namespace = _current(:Namespace)
      _build(:UML, :Package, {name: name.to_s}) do | node |
        _namespace(node, namespace, &blk)
      end
    end

    def namespace name, &blk
      # binding.pry
      namespace = _current(:Namespace)
      _build(:UML, :Namespace, {name: name.to_s}) do | node |
        _namespace(node, namespace, &blk)
      end
    end

    def class_ name, *args, &blk
      args, props = _args_opts(args,
        isAbstract: false,
        isActive: false,
      )
      _args_flags(args, props,
        isAbstract: true,
        isActive: true,
      )
      namespace = _current(:Namespace)
      props[:name] = name.to_s
      _build(:UML, :Class, props) do | node |
        _with(node, :Classifier) do
          node.ownedAttribute = UniqueArray.new
          node.ownedOperation = UniqueArray.new
          node.generalization = UniqueArray.new
          node.superClass = UniqueArray.new
          _namespace(node, namespace, &blk)
        end
      end
    end

    def superClass *names
      cls = _current(:Class)
      names.each do | name |
        cls.superClass << Misc.or_die(_find_node(cls, name))
      end
    end
    alias_method :superclass, :superClass

    def stereotype *names
      node = _current(:Namespace)
      names.each do | name |
        _add_stereotype(node, name)
      end
    end

    def generalization *args
      specific = _current(:Classifier)
      args.each do | name |
        name = name.to_s
        gen = _build(:UML, :Generalization, {})
        general = _find_node(specific, name)
        # if general is not found, yet, just store the name:
        gen.general = general || name
        gen.specific = specific
        specific.generalization << gen
        general.generalization << gen if general
        # binding.pry
      end
    end

    def property notation, &blk
      owner = _current(:Class)
      prop = @notation.property(notation)
      raise "property : #{notation.inspect}" unless prop
      _setup_property(prop, owner)
      prop._.blk = blk
      prop
    end

    def _setup_property(prop, owner)
      prop.class = owner
      prop.owner = owner
      binding.pry unless owner.ownedAttribute
      owner.ownedAttribute << prop
      prop.namespace = owner
      owner.ownedElement << prop
      prop.association = nil
      prop.owningAssociation = nil
      prop._.type_name ||= prop.type
      prop.type = Misc.or_die(_find_node(prop, prop.type)) { "cannot find #{prop.type.inspect}"}
      prop
    end

    def association *notations, &blk
      owner = _current(:Namespace)
      opts = {isDerived: false}
      opts.update(notations.pop) if Hash === notations[-1]
      raise ArgumentError, "#{owner} #{notations.size}" if notations.size != 2

      association = _build(:UML, :Association, opts)
      association.owner = owner
      association.namespace = owner
      owner.ownedElement << association
      association.ownedEnd = UniqueArray.new
      association.navigableOwnedEnd = UniqueArray.new
      association.memberEnd = UniqueArray.new

      props = notations.map do | notation |
        prop = @notation.property(notation)
        # binding.pry
        prop._.type_name ||= prop.type
        prop.type = Misc.or_die(_find_node(association, prop.type))  { "#{association.inspect} : cannot find #{prop.type.inspect}"}
        prop
      end
      [props, props.reverse].each do | (p1, p2) |
        p1.opposite = p2
        p1.owner = p2.type
        # binding.pry
      end
      props.each do | prop |
        owner = prop.owner
        # binding.pry unless owner && owner.ownedAttribute
        _setup_property(prop, prop.owner)

        association.ownedEnd << prop
        prop.owningAssociation ||= association

        prop.association ||= association
        association.navigableOwnedEnd << prop

        prop.association ||= association
        association.memberEnd << prop
        prop
      end
      # binding.pry
    end

    def _find_property(notation, owner)
      node = @notation.property(notation)
      owner = _find_node(node, node.type)
      owner = owner[0] if ::Array === owner
      # binding.pry unless owner
      if (prop = navigator.ownedElement_by_name(owner, node.name))
        prop.subsets.concat(mode.subsets).uniq!
        binding.pry
      else
        prop = node
        node.class = owner
        node.class.ownedAttribute << node
        node.owner = owner
        node.namespace = owner
        node.namespace.ownedElement << node
        node.association = nil
        node.owningAssociation = nil
        node.opposite = nil
      end
      prop
    end

    def operation notation, &blk
      node = @notation.operation(notation)
      raise "operation : #{notation.inspect}" unless node
      node.class = _current(:Class)
      node.class.ownedOperation << node
      if blk
        node.parameter = blk.parameters.map do |(_kind, name)|
          _ruby_parameter(name, direction: :in)
        end
        node.parameter << _ruby_parameter("return", direction: :return)
      end
      node.parameter.each do | param |
        param.operation = node
        param.owner = node
      end
    end
    # alias_method :method, :operation

    def constant name, value=nil, &blk
      raise "Unimplemented"
    end

    def import ns, params = {}
      dst = _current(:Namespace)
      if ::Module === ns
        src = _get_module_proxy(ns)
      else
        name = ns.to_s
        src = Misc.or_die(_find_node(dst, name)) do
          "import : #{dst.name} : cannot find #{name.inspect}"
        end
      end
      (dst.importedPackage ||= UniqueArray.new) << src
    end

    def x_import name, params = {}
      dst = _current(:Namespace)
      params = {visibility: :public}.merge(params)
      # !!! resolve package
      package = _build(:UML, :Package, {name: name})
      package.importingNamespace ||= UniqueArray.new
      packageImport = _build(:UML, :PackageImport, params)
      packageImport.importedPackage = package
      package.importingNamespace << packageImport

      package.ownedElement.select(&:name).each do | elem_name |
        params = {alias: nil, visibility: public}
        elementImport = _build(:UML, :PackageImport, params)
        elementImport.importingNamespace = pack
      end
    end

    def _ruby_parameter name, props
      _build(:UML, :Parameter, {
          name: name,
          type: nil, # Ruby parameters are untyped,
          direction: :in,
          lower: 1,
          upper: 1,
          default: [],
        }.merge(props)
      )
    end

    def enum *names
      owner = _current(:Class)
      _add_stereotype(owner, "enumeration")
      owner.ownedLiteral ||= UniqueArray.new
      names.each do | name |
        name = name.to_s
        enum = _build(:UML, :EnumerationLiteral, {name: name})
        enum.classifer = owner
        owner.ownedLiteral << enum
      end
    end

    #####################################

    def _namespace node, namespace, &blk
      node.namespace = namespace
      node.namespace.ownedElement << node if node.namespace
      node.owner = node.namespace
      node.stereotype = UniqueArray.new
      _with(node, :Namespace, &blk)
    end

    def _add_stereotype(node, name)
      stereotype = _get_stereotype(name)
      node.stereotype ||= UniqueArray.new
      node.stereotype << stereotype
    end

    def _get_stereotype(name)
      name = name.to_s
      (@stereotypes[name] ||= _build(:UML, :Stereotype, {name: name}))
    end

    def _get_module_proxy(mod)
      full_path = mod.to_s
      @module_proxy[mod.to_s] ||= begin
        node = @native[mod]
        @root.ownedElement << node
        # puts("_get_module_proxy(#{mod}) -> #{node.inspect}")
        node
      end
    end

    def _build(ns, meta, properties, blk=nil)
      node = @factory.new(ns, meta, properties)
      node_parent = _current(:node)
      node_parent._.node_children << node if node_parent
      node.owner = node_parent
      node.ownedElement = UniqueArray.new # !!!
      node_parent.ownedElement << node if node_parent
      # node.stereotype = UniqueArray.new
      node._.to_h.update(
        meta: meta,
        blk: blk,
        node_parent: node_parent,
        node_children: UniqueArray.new,
        ruby_native: false,
        ruby_include: UniqueArray.new,
        ruby_extend: UniqueArray.new,
        ruby_module: nil,
        # object_id: (@object_id += 1),
      )
      @created << node
      if block_given?
        _with(node, :node) do
          _with(node, meta) do
            yield node
          end
        end
      end
      node
    end

    def _args_opts args, defaults={}
      opts = ::Hash === args[-1] ? args.pop : {}
      [args, defaults.merge(opts)]
    end

    def _args_flags args, opts, flags
      flags.each do | arg, value |
        opts[arg] = value if args.include?(arg)
      end
      opts
    end

    def _type_to_node x
      case type
      when nil, Compiler::AST::Node
        x
      when Module
        _get_module_proxy(x)
      when Symbol, String
        x
      else
        raise "_to_class"
      end
    end

    def _find_node(node, name)
      return name if ::RUML::Compiler::AST::Node === name
      result = navigator.find_node_scoped(node.namespace, name.to_s)
      result = result[0] if ::Array === result
      result
    end

    def _name arg
      case arg
      when ::String, ::Symbol then arg.to_s
      when Compiler::AST::Node then arg.name
      end
    end

    def _desc node
      path_str = navigator.namespace_str(node)
      "#{self.class} #{node.inspect} @ #{path_str}"
    end

    def _current(name)
      @contexts[name.to_sym].current
    end

    def _with(node, name=nil, &blk)
      name ||= node._.meta.to_sym
      @contexts[name].with(node, &blk)
    end

    def compile(opts = { })
      opts = @opts.merge(opts)
      c = Compiler::Frontend.new(opts)
      c.run(@root)
      target = c.target
      # puts(target.to_s)
      # binding.pry
      c
    end

    #####################################

    def inspect detail=false
      return super() if detail
      "#<#{self.class} ...>"
    end
  end
end
