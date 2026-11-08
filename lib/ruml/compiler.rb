# frozen_string_literal: true

require 'ruml'
require 'rmof/runtime'
require 'ruml/logging'
require 'ruml/ast'
require 'rmof/code_generator'
require 'method_source'

module RUML
  class Compiler
    class Error < StandardError ; end
    include RUML::Logging
    EMPTY_ARRAY = [ ].freeze unless defined? EMPTY_ARRAY

    # Inputs:
    attr_reader :target, :pass

    # Outputs:
    attr_reader :created, :module_to_node

    def initialize opts = nil, &blk
      opts ||= { } # EMPTY_HASH
      @opts = opts
      self._log_verbose = true # @opts[:verbose]
      @created = [ ]
      @target = opts[:target]
      @current = nil
      @current_stack = [ ]
      @module_to_node = { }
      @pass = 1
      @code_generator = ::RMOF::CodeGenerator.new
      raise ArgumentError, ":target not a Module : #{@target.inspect}" unless Module === @target
    end

    def run node
      compile(node)
    end

    def compile node
      meta = node._.meta
      sel = [ :"compile_#{meta}_#{pass}", :"compile_#{meta}" ].find do | sel |
        respond_to?(sel)
      end
      if sel
        _log { "#{sel.inspect} : #{node._}" }
        send(sel, node)
      else
        _log { "no handler : #{node._}" }
        # binding.pry
        _compile_ownedElement(node)
      end
    end

    def compile_root_1 node
      # binding.pry
      node.ownedElement.each {|x| compile(x) }
      @pass = 2
      node.ownedElement.each {|x| compile(x) }
    end

    def compile_class node
      send("compile_namespace_#{pass}", node)
    end

    def compile_package node
      # binding.pry
      node._.superClass_remaining ||= []
      send("compile_namespace_#{pass}", node)
    end

    def compile_namespace_1 node
      raise "target is nil" if target.nil?

      path = node._.namespace_path
      node_path_str = path.map(&:name).compact.join("::")
      full_path_str = @target.to_s + "::" + node_path_str
      node._.to_h.update(
        path: path,
        node_path_str: node_path_str,
        full_path_str: full_path_str,
      )
      _log { "#{full_path_str} { " }

      kind = META_TO_MODULE_CLASS.fetch(node._.meta)
      declaration = "#{kind} #{full_path_str}"

      if node._.meta == :class
        supers = node.superClass.map{|super_| resolve(node.namespace, super_)}
        if super_ = supers.shift
          declaration << " < #{super_._.full_path_str}"
        end
        node._.superClass_remaining = supers
      end

      lines = [""]
      lines << declaration
      lines << "  module RUML_InstanceBehavior"
      lines << "  end"
      lines << "  module RUML_ModuleBehavior"
      lines << "  end"
      lines << "  def self.included(target)"
      lines << "    target.include(RUML_InstanceBehavior)"
      lines << "    target.extend(RUML_ModuleBehavior)"
      lines << "  end"
      lines << "  self"
      lines << "end"
      lines << ""

      target = node_eval(node, lines)
      node._module = target
      @module_to_node[target] = node
      target.const_set(:RUML_COMPILER_NODE, node)
      @created << target

      _compile_ownedElement(node)

      _log { "}" }
    end

    META_TO_MODULE_CLASS = {
      package: "module",
      namespace: "module",
      class: "class",
      root: nil,
    }.freeze

    def compile_namespace_2 node
      # binding.pry if node.name == "C4"
      _compile_ownedElement node
      _compile_children node, :stereotype, :import
      _compile_generalization node
      _compile_children node, :property, :association, :method, :constant
    end

    def _compile_generalization node
      node_path = node._.full_path_str
      parent = node.namespace

      node.generalization ||= []
      generals = node.generalization.map(&:general)
      generals.map!{|g| parent._._find(g)._.full_path_str}

      lines = []
      if node._.isAbstract
        lines << "#{node_path}.include(::RMOF::Runtime::Uninstantiatable)"
      else
        lines << "#{node_path}.include(::RMOF::Runtime::Instantiable)"
      end
      node._.superClass_remaining.each do | super_ |
        gem_path = parent._.find(super_)._.full_path_str
        lines << "#{node_path}.include(#{gen_path}::RUML_InstanceBehavior)"
      end
      generals.each do | gen_path |
        lines << "#{node_path}.include(#{gen_path}::RUML_InstanceBehavior)"
      end
      lines << "#{node_path}.include(#{node_path}::RUML_InstanceBehavior)"
      lines << "#{node_path}.extend(#{node_path}::RUML_ModuleBehavior)"

      node_eval(node, lines)
    end

    def compile_operation_2 node
      name = node.name.to_sym
      parent = node.namespace
      expr = parent._.full_path_str.dup
      if node._.isClassMethod
        expr << "::RUML_ModuleBehavior"
      else
        expr << "::RUML_InstanceBehavior"
      end
      target = lookup_module(expr)
      # binding.pry if node.name == "unbounded"
      node_define_method(parent, target, name, node._.blk)
    end

    def compile_constant_2 node
      name = node.name.to_sym
      target = node.namespace._.module
      return if target.constants.include?(name)
      val = args[1]
      val = target.instance_eval(&node.blk) if node.blk
      _log { "  constant #{node.name.inspect} = #{node.val.inspect}" }
      node_const_set(node.namespace, target, name, val)
    end

    def compile_import_2 node
      parent = node.namespace
      dst = node._.module
      node.args.flatten.each do | name |
        src = resolve(parent, name).module
        src.constants.each do | n |
          v = x.const_get(n)
          dst.const_set(n, v)
          _log { "  import #{dst}::#{n} = #{x}::#{n}" }
        end
      end
    end

    def compile_stereotype_2 node
      args = node._.args
      # @target.stereotype *args
    end

    def compile_property_2 node
      node.type = node._.find(node.type) or raise "Cannot find type for #{node.inspect}"
      # binding.pry
      @code_generator.generate_property(node)
    end

    def compile_association_2 node
      args = node._.args
      owner = node.namespace
      args[1] = resolve(owner, args[1])._.full_path_str
      args[5] = resolve(owner, args[5])._.full_path_str
      @code_generator.generate_association(target, *args)
    end

    ######################################################

    def _compile_ownedElement node
      inside_namespace node do
        (node.ownedElement || EMPTY_ARRAY).each do | child |
          compile(child)
        end
      end
    end

    def _compile_children node, *names
      inside_namespace(node) do
        names.each do | name |
          (node[name] || EMPTY_ARRAY).each do | x |
            compile x
          end
        end
      end
    end

    def inside_namespace node, &blk
      @current_stack.push @current
      begin
        @current = node
        yield node
      ensure
        @current = @current_stack.pop
      end
    end

    def node_const_set(node, target, name, value)
      getter = lambda { value }
      name_upper = name.to_s.upper.to_sym
      expr = node_code(node, "#{node._.full_path_str}.const_set(#{name_upper.inspect}, #{value.inspect})")
      target.const_set(name_upper, value)
      node_define_method(node, target, name, getter)
    end

    def node_define_method(node, target, name, blk)
      _log { "node_define_method : def #{node._}.#{name}(...)"}
      blk_source = blk.source.sub(/\A.*?(?=\bdo\b|\{)/m, "")
      expr = node_code(node, "#{target}.define_method(#{name.inspect}) #{blk_source}\n")
      target.define_method(name, &blk)
    end

    def node_eval(node, expr)
      _log { "node_eval : #{node.inspect}" }
      expr = node_code(node, expr)
      ::Kernel.eval(expr)
    rescue => e
      # binding.pry
      raise Error, "#{e.inspect} : in \n#{expr}"
    end

    def node_code(node, expr)
      if ::Array === expr
        expr = expr.map(&:to_s).join("\n")
      end
      expr = <<"DESC"

# #########################################
# #{node.inspect}
#{expr}
# #########################################

DESC
      _log { expr }
      expr
    end

    def resolve node, name
      return @module_to_node[name] if @module_to_node[name]
      return name if AST::Node === name
      name = name.to_s
      while node
        if found = node._.find(name)
          return found
        end
        node = node.namespace
      end
    end

    def lookup_module str
      path = str.split("::")
      path.inject(::Object) do | mod, name |
        mod.const_get(name)
      end
    end

    def namespace_str path
      path.map{|node| node.name}.compact.map(&:to_s).join("::")
    end

    def _log_prefix ; "pass #{pass}" ; end
  end
end
