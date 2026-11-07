require 'ruml'
require 'ruml/support'
require 'ruml/logging'
require 'ruml/ast'

module RUML
  class Compiler
    include RUML::Support::CodeGeneration, Logging
    EMPTY_ARRAY = [ ].freeze unless defined? EMPTY_ARRAY

    # Inputs:
    attr_reader :target, :pass

    # Outputs:
    attr_reader :created, :path_to_module

    def initialize opts = nil, &blk
      opts ||= { } # EMPTY_HASH
      @opts = opts
      self._log_verbose = true # @opts[:verbose]
      @created = [ ]
      @target = @opts.fetch(:target)
      @target_stack = [ ]
      @current = nil
      @current_stack = [ ]
      @pass = 1
      @path_to_module = { }
      raise ArgumentError, ":target not a Module : #{@target.inspect}" unless Module === @target
    end

    def compile node
      raise "node is nil" if node.nil?
      sel = [ :"compile_#{node.meta}_#{pass}", :"compile_#{node.meta}" ].find do | sel |
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
      @pass += 1
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
      meta, type, name, args, blk = node.to_h.project(:meta, :type, :name, :args, :blk)

      lines = [""]
      path = node._namespace_path
      path.reject!{|ns| ! ns.name}
      node_path_str = path.map(&:name).join("::")
      full_path_str = @target.to_s + "::" + node_path_str
      _log { "#{full_path_str} { " }

      pp(node: node, path: path, full_path_str: full_path_str)

      generalizations = node.generalizations&.dup || []
      meta_kind = {
        package: "module",
        namespace: "module",
        class: "class",
        root: nil,
      }
      kind = meta_kind.fetch(node.meta)
      lines << "#{kind} #{full_path_str}"
      lines << "  module RUML_InstanceBehavior"
      # If it's a non-abstract class, make it instantiable.
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
      # target.const_set(:RUML_COMPILER_NODE, node)
      @created << target

      node_info = AST::Node.new(
        path: path,
        node_path_str: node_path_str,
        full_path_str: full_path_str,
        generalizations: generalizations,
        module: @target,
      )
      node._info = node_info
      _compile_ownedElement(node)

      _log { "}" }
    end

    def compile_namespace_2 node
      _compile_ownedElement(node)
      _compile_children(node, :stereotype, :import, :constant, :property, :method)
      _compile_generalizations node
      _compile_children(node, :association)
    end

    def _compile_generalizations node
      generalizations = node.generalization || EMPTY_ARRAY
      lines = []
      node_path = node._info.full_path_str
      if isAbstract(node)
        lines << "#{node_path}.include(::RUML::Support::Uninstantiable)"
      else
        lines << "#{node_path}.include(::RUML::Support::Instantiable)"
      end
      generalizations.each do | gen |
        gen_path = gen._info.full_path_str
        lines << "#{node_path}.include(#{gen_path})"
      end
      node_eval(node, lines)
    end

    def compile_method_2 node
      name = node.name.to_sym
      parent = node.namespace
      expr = parent._info.full_path_str.dup
      if isClassMethod(node)
        expr << "::RUML_ModuleBehavior"
      else
        expr << "::RUML_InstanceBehavior"
      end
      target = lookup_module(expr)
      _log { "\nexpr=#{expr.inspect}\n" }
      _log { "\ntarget=#{target.inspect}\n"  }
      target.define_method(name, &node.blk)
      binding.pry

      # _log { "    => pim #{(target.public_instance_methods.sort - Object.methods).inspect}" }
      # _log { "    => sm  #{(target.methods.sort - Object.methods).inspect}" }
    end

    def compile_constant_2 node
      name = node.name.to_sym
      return if target.constants.include?(name)
      val = target.instance_eval(&node.blk) if node.blk
      _log { "  constant #{node.name.inspect} = #{node.val.inspect}" }
      target.const_set(name.to_s.upper.to_sym, val)
      target.meta_def(name) { || val }
      target.class_def(name) { || val }
    end

    def compile_import node
      args = node.args
      args.flatten.each do | x |
        x.constants.each do | n |
          cv = x.const_get(n)
          _log { "  import #{target}::#{n} = #{x}::#{n}" }
          target.const_set(n, cv)
        end
      end
    end

    def compile_stereotype_2 node
      args = node.args
      @target.stereotype *args
    end

    def compile_property_2 node
      args = node.args.dup
      args[1] = _type(args[1]) || (raise "Cannot find type for #{node.inspect}")
      _generate_property target, *args
    end

    def compile_association_2 node
      args = node.args.dup
      args[1] = _type(args[1]) || target
      args[5] = _type(args[5]) || target
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

    def isClassMethod node
      node.meta == :method && node.args.include?(:class)
    end

    def isAbstract node
      while node
        return true if node.meta == :class && node.isAbstract
        node = node.namespace
      end
      false
    end

    def inside_namespace node, &blk
      @target_stack.push @target
      @current_stack.push @current
      begin
        @current = node
        @target = node._info.module if node._info
        yield node
      ensure
        @target = @target_stack.pop
        @current = @current_stack.pop
      end
    end

    def node_eval(node, expr)
      expr = expr.join("\n") if ::Array === expr
      _log { "node_eval : pass=#{pass} : #{node.inspect}"}
      _log { "#{expr}" }
      ::Kernel.eval(expr)
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
  end # Compiler
end # RUML

