# frozen_string_literal: true

require 'ruml'
require 'ruml/core/runtime'
require 'ruml/support/logging'
require 'ruml/compiler/ast'
require 'ruml/compiler/target/ruby'
require 'method_source'

module RUML
  module Compiler
  class Compiler
    class Error < StandardError ; end
    include RUML::Support::Logging::Basic
    EMPTY_ARRAY = [ ].freeze unless defined? EMPTY_ARRAY

    # Inputs:
    attr_reader :target, :pass

    # Outputs:
    attr_reader :created_modules, :module_to_node

    def initialize opts = nil, &blk
      opts ||= { } # EMPTY_HASH
      @opts = opts
      @created_modules = [ ]
      @target = opts[:target]
      @current = nil
      @current_stack = [ ]
      @module_to_node = { }
      @pass = 1
      @code_generator = RUML::Compiler::Target::Ruby.new
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
        log { "#{sel.inspect} : #{node._}" }
        send(sel, node)
      else
        log { "no handler : #{node._}" }
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
      log { "#{full_path_str} { " }

      kind = META_TO_MODULE_CLASS.fetch(node._.meta)
      declaration = "#{kind} #{full_path_str}"

      if node._.meta == :class
        supers = node.superClass.map{|super_| lookup_node(node.namespace, super_)}
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

      module_ = node_eval(node, lines)
      node._.ruby_module = module_
      node._.ruby_module_instance = module_.const_get("RUML_InstanceBehavior")
      node._.ruby_module_module = module_.const_get("RUML_ModuleBehavior")
      node._.ruby_include&.each do | m |
        module_.include(m)
      end
      node._.ruby_extend&.each do | m |
        module_.extend(m)
      end
      target.const_set(:RUML_COMPILER_NODE, node)

      @module_to_node[module_] = node
      @created_modules << module_

      _compile_ownedElement(node)

      log { "}" }
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
        lines << "#{node_path}.include(::RUML::Core::Runtime::Uninstantiatable)"
      else
        lines << "#{node_path}.include(::RUML::Core::Runtime::Instantiable)"
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
      target = node._.isStatic ? parent._.ruby_module_module : parent._.ruby_module_instance
      # binding.pry if node.name == "unlimited"
      node_define_method(parent, target, name, node._.blk)
    end

    def compile_constant_2 node
      name = node.name.to_sym
      target = node.namespace._.ruby_module
      return if target.constants.include?(name)
      val = args[1]
      val = target.instance_eval(&node.blk) if node.blk
      log { "  constant #{node.name.inspect} = #{node.val.inspect}" }
      node_const_set(node.namespace, target, name, val)
    end

    def compile_import_2 node
      parent = node.namespace
      dst = node._.ruby_module
      node.args.flatten.each do | name |
        src = lookup_node(parent, name).ruby_module
        src.constants.each do | n |
          v = x.const_get(n)
          dst.const_set(n, v)
          log { "  import #{dst}::#{n} = #{x}::#{n}" }
        end
      end
    end

    def compile_stereotype_2 node
      args = node._.args
      # @target.stereotype *args
    end

    def compile_property_2 node
      node.type = lookup_node(node.namespace, node.type)
      result = @code_generator.generate_property(node)
      # binding.pry
      node_module_eval(node, result[:code], node.class._.ruby_module_instance)
    end

    def compile_association_2 node
      args = node._.args
      owner = node.namespace
      args[1] = lookup_node(owner, args[1])._.full_path_str
      args[5] = lookup_node(owner, args[5])._.full_path_str
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
      log { "node_define_method : def #{node._}.#{name}(...)"}
      blk_source = blk.source.sub(/\A.*?(?=\bdo\b|\{)/m, "")
      expr = node_code(node, "#{target}.define_method(#{name.inspect}) #{blk_source}\n")
      target.define_method(name, &blk)
    end

    def node_module_eval(node, expr, mod)
      expr = node_code(node, expr)
      mod.module_eval(expr)
    rescue => e
      # binding.pry
      raise Error, "#{e.inspect} : in \n#{expr}"
    end

    def node_eval(node, expr)
      log { "node_eval : #{node.inspect}" }
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
      log { expr }
      expr
    end

    def lookup_node node, ident
      return ident if AST::Node === ident
      if ::Module === ident and x = @module_to_node[ident]
        return x
      end
      ident = ident.to_s
      while node
        if found = node._.find(ident)
          return found
        end
        node = node.namespace
      end
    end

    def lookup_module ident, fail_if_not_found=false
      if ::Module === ident
        ident
      elsif AST::Node === ident && ident._.ruby_module
        ident._.ruby_module
      else
        path = ident.to_s.split("::")
        path.inject(::Object) do | mod, name |
          name = name.to_sym
          return if fail_if_not_found && ! mod.const_defined?(name)
          mod.const_get(name)
        end
      end
    end

    def namespace_str path
      path.map(&:name).compact.map!(&:to_s).join("::")
    end

    def _log_prefix ; "pass #{pass}" ; end
  end
  end
end
