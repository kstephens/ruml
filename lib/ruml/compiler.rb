# frozen_string_literal: true

require 'ruml'
require 'ruml/support'
require 'ruml/logging'
require 'ruml/ast'
require 'method_source'

module RUML
  class Compiler
    class Error < StandardError ; end
    include RUML::Support::CodeGeneration, Logging
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
      _log { "compile : pass=#{pass} : sel=#{sel.inspect} : #{node.inspect}" }
      if sel
        send(sel, node)
      else
        _log { "compile : WARNING : no handler" }
        _compile_ownedElement(node)
      end
    end

    def compile_root_1 node
      node.ownedElement.each { | x | compile(x) }
      @pass = 2
      node.ownedElement.each { | x | compile(x) }
    end

    def compile_class node
      send("compile_namespace_#{pass}", node)
    end

    def compile_package node
      send("compile_namespace_#{pass}", node)
    end

    def compile_namespace_1 node
      raise "target is nil" if target.nil?

      path = node._.namespace_path
      node_path_str = path.map(&:name).compact.join("::")
      full_path_str = @target.to_s + "::" + node_path_str
      _log { "#{full_path_str} { " }

      meta_kind = {
        package: "module",
        namespace: "module",
        class: "class",
        root: nil,
      }
      kind = meta_kind.fetch(node._.meta)
      lines = [""]
      lines << "#{kind} #{full_path_str}"
      lines << "  module RUML_InstanceBehavior"
      lines << "  end"
      lines << "  module RUML_ModuleBehavior"
      lines << "  end"
      lines << "  def self.included(target)"
      lines << "    target.include(RUML_InstanceBehavior)"
      lines << "    target.extend(RUML_ModuleBehavior)"
      lines << "  end"
      lines << "end"
      lines << ""

      target = node_eval(node, lines)
      @module_to_node[target] = node
      # target.const_set(:RUML_COMPILER_NODE, node)
      @created << target

      node._.to_h.update(
        path: path,
        node_path_str: node_path_str,
        full_path_str: full_path_str,
        module: target,
      )
      _compile_ownedElement(node)

      _log { "}" }
    end

    def compile_namespace_2 node
      _compile_ownedElement(node)
      _compile_children(node, :stereotype, :import)
      # binding.pry if node.name == "Cls4"
      _compile_generalizations node
      _compile_children(node, :property, :association, :method, :constant)
    end

    def _compile_generalizations node
      raise unless node
      lines = []
      node_path = node._.full_path_str
      gens = (node.generalization || EMPTY_ARRAY).map do | name |
        gen = resolve(node, name)
        gen._.full_path_str
      end
      if node._.isAbstract
        gens << "::RUML::Support::Uninstantiable"
      else
        gens << "::RUML::Support::Instantiable"
      end
      gens.each do | gen_path |
        lines << "#{node_path}.include(#{gen_path})"
      end
      lines << "#{node_path}.include(#{node_path}::RUML_InstanceBehavior)"
      lines << "#{node_path}.extend(#{node_path}::RUML_ModuleBehavior)"
      node_eval(node, lines)
    end

    def compile_method_2 node
      name = node.name.to_sym
      parent = node.namespace
      expr = parent._.full_path_str.dup
      if node._.isClassMethod
        expr << "::RUML_ModuleBehavior"
      else
        expr << "::RUML_InstanceBehavior"
      end
      target = lookup_module(expr)
      node_define_method(parent, target, name, node.blk)
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
      args = node.args
      # @target.stereotype *args
    end

    def compile_property_2 node
      args = node.args.dup
      args[1] = _type(args[1]) || (raise "Cannot find type for #{node.inspect}")
      _generate_property target, *args
    end

    def compile_association_2 node
      args = node.args.dup
      owner = node.namespace
      args[1] = resolve(owner, args[1])
      args[5] = resolve(owner, args[5])
      _generate_association *args
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
      name_upper = name.to_s.upper.to_sym
      expr = node_code(node, "#{node._.full_path_str}.const_set(#{name_upper.inspect}, #{value.inspect})")
      target.const_set(name_upper, value)
      blk = lambda { value }
      node_define_method(node, target, name, blk)
    end

    def node_define_method(node, target, name, blk)
      _log { "node_define_method : #{node.inspect}"}
      _log { "blk = #{blk.source}" }
      expr = node_code(node, "#{node._.full_path_str}.define_method(#{name.inspect}, &blk)")
      target.define_method(name, &blk)
    end

    def node_eval(node, expr)
      _log { "node_eval : #{node.inspect}" }
      expr = node_code(node, expr)
      ::Kernel.eval(expr)
    rescue => e
      binding.pry
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
