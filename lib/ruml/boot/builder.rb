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

    class BuilderError < RUML::Error; end
    class UnresolvedError < BuilderError; end

    Misc = ::RUML::Support::Misc
    UniqueArray = ::RUML::Core::Misc::UniqueArray
    RetryOn = RUML::Core::Navigation::NavigationError

    include Support::Logging
    attr_reader :created, :root, :root_node, :contexts, :navigator

    def initialize opts = nil, &blk
      @opts = opts || {}
      @_log_verbose = true # @opts[:verbose]
      @root_module = @opts[:root]
      @factory = RUML::Boot::Factory.new(root: @root_module)
      @notation = RUML::Core::Notation.new(@factory)
      @contexts = ::RUML::Support::Contexts.new
      @navigator = @n = RUML::Core::Navigation::Navigator.new
      @native = RUML::Compiler::Native.new
      @_find_or = {}
      @_with_retry = []
      @created = [ ]
      @stereotypes = {}
      @object_id = 0
      @module_proxy = {}
      @native_root = @native[@opts.fetch(:root)]
      @root_node = _build(:RUML, :Root, {}) do | node |
        node.owner = @native_root
        node.ownedElement ||= UniqueArray.new
        node.importedPackage ||= UniqueArray.new
      end
      _start(&blk) if block_given?
      self
    end

    def _start &blk
      _with(@root_node, :Root) do
        _with(@root_node, :Namespace) do
          @result = instance_eval(&blk)
        end
      end
      # _end()
      # self
    end

    def _with_retry &blk
      yield
    # rescue RetryOn
    #   binding.pry
    #   @_with_retry << blk
    end

    def _end # !!! unused
      total = @_with_retry.size
      while @_with_retry.size < total
        until @_with_retry
          # puts(@_with_retry.size)
          blk = @_with_retry.shift
          begin
            blk.call
          rescue RetryOn
            @_with_retry << blk
          end
        end
      end
    end

    # Include a native Ruby Module into a UML namespace:
    def include *modules
      (_current(:Namespace)._.ruby_include ||= UniqueArray.new).concat(modules)
    end
    def extend *modules
      (_current(:Namespace)._.ruby_extend ||= UniqueArray.new).concat(modules)
    end

    def package name, &blk
      namespace = _current(:Namespace)
      package = _current(:Package)
      _build(:UML, :Package, {name: name.to_s}, [name]) do | node |
        node.nestingPackage = package
        (package.nestedPackage ||= UniqueArray.new) << node if package
        _with_namespace(node, namespace, &blk)
      end
    end

    def namespace name, &blk
      _with_retry do
        _namespace name, blk
      end
    end

    def _namespace name, blk
      namespace = _current(:Namespace)
      _build(:UML, :Namespace, {name: name.to_s}) do | node |
        _with_namespace(node, namespace, &blk)
      end
    end

    def class_ name, *args, &blk
      _with_retry do
        _find_or(:UML, :Class, [name]) do
          _class_(name, args, blk)
        end
      end
    end

    def _class_ name, args, blk
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
      _build(:UML, :Class, props, [name]) do | node |
        _with(node, :Classifier) do
          node.ownedAttribute = UniqueArray.new
          node.ownedOperation = UniqueArray.new
          node.generalization = UniqueArray.new
          node.superClass = UniqueArray.new
          _with_namespace(node, namespace, &blk)
        end
      end
    end

    def superClass *names
      names.each do | name |
        _with_retry do
          _superClass(name)
        end
      end
    end
    alias_method :superclass, :superClass

    def _superClass name
      name = name.to_s
      cls = _current(:Class)
      scls = _find_node_scoped(cls.owner, name)
      raise BuilderError, "#{navigator.path_str(cls)} superClass : cannot find #{name.inspect}" unless scls
      cls.superClass << scls
    end

    def stereotype *names
      node = _current(:Namespace)
      names.each do | name |
        _add_stereotype(node, name)
      end
    end

    def generalization *args
      specific = _current(:Classifier)
      args.each do | name |
        _with_retry do
          _generalization specific, name
        end
      end
    end

    def _generalization specific, name
      name = name.to_s
      gen = _build(:UML, :Generalization, {})
      general = _find_node_scoped(specific.owner, name)
      # binding.pry
      # if general is not found, yet, just store the name:
      gen.general = general || name
      gen.specific = specific
      specific.generalization ||= UniqueArray.new
      specific.generalization << gen
      general.generalization ||= UniqueArray.new if general
      general.generalization << gen if general
      # binding.pry
    end

    def property notation, &blk
      owner = _current(:Class)
      _with_retry do
        _property notation, owner, blk
      end
    end

    def _property notation, owner, blk
      prop = @notation.property(notation)
      raise BuilderError, "property : #{notation.inspect}" unless prop
      _setup_property(prop, owner)
      prop._.blk = blk
      prop
    end

    def _setup_property(prop, owner)
      prop._.type_name ||= prop.type
      prop.type = _find_node_scoped(owner, prop.type) || prop.type
      prop.class ||= owner
      prop.owner ||= owner
      # binding.pry if prop._.notation =~ /String/
      owner.ownedAttribute << prop unless @n.isNativeModule?(owner)
      prop.namespace = owner
      owner.ownedElement << prop unless navigator.isNativeModule?(owner)
      prop.association = nil
      prop.owningAssociation = nil
      # binding.pry
      prop
    end

    def association *notations, &blk
      notations = notations.dup
      # pp(notations: notations)
      # pp(caller.select{|x| x =~ %r{/model\.rb|retry}})
      opts = {isDerived: false}
      opts.update(notations.pop) if Hash === notations[-1]
      owner = _current(:Namespace)
      # binding.pry if notations.empty?
      raise BuilderError, "association : #{owner.inspect} #{notations.size}" if notations.size != 2
      _with_retry do
        _association notations, opts, owner, blk
      end
    end

    def _association notations, opts, owner, blk
      props = notations.map do | notation |
        prop = @notation.property(notation)
        raise BuilderError, "association : #{notation.inspect}" unless prop
        prop._.type_name ||= prop.type
        prop.type = _find_node_scoped(owner, prop.type) || prop.type
        binding.pry if ::String === prop.type
        prop
      end
      [props, props.reverse].each do | (p1, p2) |
        p1.opposite = p2
        p1.owner = p2.type
        p1.class = p2.owner
        # binding.pry
      end

      association = _build(:UML, :Association, opts)
      association.owner = owner
      association.namespace = owner
      association.ownedEnd = UniqueArray.new
      association.navigableOwnedEnd = UniqueArray.new
      association.memberEnd = UniqueArray.new

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

      owner.ownedElement << association
      # binding.pry
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

    def import name, params = {}
      dst = _current(:Namespace)
      name = @native[name]
      src = _find_node_scoped(dst, name)
      _package_import dst, src
    end

    def _package_import namespace, package
      import = _build(:UML, :PackageImport, {visibility: :public})
      package = _find_node_scoped(namespace, package)
      import.importedPackage = package
      import.importingNamespace = namespace
      namespace.packageImport << import
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

    def _with_namespace node, namespace, &blk
      node.namespace = namespace
      node.namespace.ownedElement << node if node.namespace
      node.owner = node.namespace
      node.stereotype ||= UniqueArray.new
      node.packageImport = UniqueArray.new
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

    def _find_or(ns, type, keys=[])
      key = [ns, type, keys, _current(:node)]
      unless (node = @_find_or[key])
        node = yield
        @_find_or[key] = node if node
      end
      node
    end

    def _build(ns, type, properties, blk=nil)
      node = @factory.new(ns, type, properties)
      node_parent = _current(:node)
      node_parent._.node_children << node if node_parent
      node.owner = node_parent
      node.ownedElement = UniqueArray.new # !!!
      node_parent.ownedElement << node if node_parent
      node.namespace = _current(:Namespace)
      # node.stereotype = UniqueArray.new
      node._.to_h.update(
        metatype: type,
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
          _with(node, type) do
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

    def _find_node_scoped node, name
      return name if ::RUML::Compiler::AST::Node === name
      node = @native[node]
      @n.find_node_scoped(node, name.to_s)
    end

    # def _find_node_or_die node, name, *args, &blk
    #   return name if ::RUML::Compiler::AST::Node === name
    #   node = @native[node]
    #   result = @n.find_node_or_die(node.namespace, name.to_s, *args, &blk)
    #   result
    # end

    def _name arg
      case arg
      when ::String, ::Symbol then arg.to_s
      when Compiler::AST::Node then arg.name
      end
    end

    def _desc node
      path_str = @n.namespace_str(node)
      "#{self.class} #{node.inspect} @ #{path_str}"
    end

    def _current(name)
      @contexts[name.to_sym].current
    end

    def _with(node, name=nil, &blk)
      name ||= node._.metatype.to_sym
      @contexts[name].with(node, &blk)
    end

    def compile(opts = { })
      opts = @opts.merge(opts)
      c = Compiler::Frontend.new(opts)
      c.run(@root_node)
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
