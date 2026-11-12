# frozen_string_literal: true

require 'ruml'
require 'ruml/compiler'
require 'ruml/core/runtime'
require 'ruml/support/logging'
require 'ruml/compiler/ast'
require 'ruml/compiler/target/ruby'

module RUML
  module Compiler
  class Frontend
    class Error < CompilerError ; end
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
      eval_code(@code_generator.to_s)
    end

    def eval_code(code)
      ::Kernel.eval(code)
    rescue
      puts code; binding.pry
      raise
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
      path = node._.namespace_path
      node_path_str = path.map(&:name).compact.join("::")
      full_path_str = @target.to_s + "::" + node_path_str
      node._.to_h.update(
        path: path,
        node_path_str: node_path_str,
        full_path_str: full_path_str,
        root_package: @target.to_s,
      )
      log { "#{full_path_str} { " }

      @code_generator.emit_namespace(node)

      _compile_ownedElement(node)

      log { "}" }
    end

    def compile_namespace_2 node
      # binding.pry if node.name == "C4"
      _compile_ownedElement node
      _compile_children node, :stereotype, :import
      _compile_generalization node
      _compile_children node, :property, :association, :method, :constant
    end

    def _compile_generalization node
      @code_generator.emit_generalization(node)
    end

    def compile_operation_2 node
      @code_generator.emit_operation(node)
    end

    def compile_constant_2 node
      @code_generator.emit_constant(node)
    end

    def compile_import_2 node
      @code_generator.emit_import(node)
    end

    def compile_stereotype_2 node
      args = node._.args
      # @target.stereotype *args
    end

    def compile_property_2 node
      @code_generator.emit_property(node)
    end

    def compile_association_2 node
      args = node._.args
      owner = node.namespace
      args[1] = lookup_node(owner, args[1])._.full_path_str
      args[5] = lookup_node(owner, args[5])._.full_path_str
      @code_generator.emit_association(target, *args)
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

    def _log_prefix ; "pass #{pass}" ; end
  end
  end
end
