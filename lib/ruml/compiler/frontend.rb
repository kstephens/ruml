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

    attr_reader :root_namespace, :pass
    attr_accessor :target, :target

    def initialize opts = nil, &blk
      opts ||= { } # EMPTY_HASH
      @opts = opts
      @created_modules = [ ]
      @root_namespace = (opts[:root_namespace] || "").to_s
      @target = opts.fetch(:target)
      @target = RUML::Compiler::Target.const_get(@target) if ::Symbol === @target
      @target = @target.new unless RUML::Compiler::Target === @target
      @current = nil
      @current_stack = [ ]
      @pass = 1
    end

    def run node
      compile(node)
    end

    def eval_code()
      ::Kernel.eval(@target.to_s)
      self
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
      full_path_str = @root_namespace.to_s + "::" + node_path_str
      node._.to_h.update(
        path: path,
        node_path_str: node_path_str,
        full_path_str: full_path_str,
        root_package: @root_namespace.to_s,
      )
      log { "#{full_path_str} { " }

      @target.emit_namespace(node)

      _compile_ownedElement(node)

      log { "}" }
    end

    def compile_namespace_2 node
      _compile_ownedElement node
      _compile_children node, :stereotype, :import
      _compile_generalization node
      _compile_children node, :property, :association, :method, :constant
    end

    def _compile_generalization node
      @target.emit_generalization(node)
    end

    def compile_operation_2 node
      @target.emit_operation(node)
    end

    def compile_constant_2 node
      @target.emit_constant(node)
    end

    def compile_import_2 node
      @target.emit_import(node)
    end

    def compile_stereotype_2 node
      args = node._.args
    end

    def compile_property_2 node
      @target.emit_property(node)
    end

    def compile_association_2 node
      args = node._.args
      owner = node.namespace
      args[1] = owner._.lookup_node(args[1])._.full_path_str
      args[5] = owner._.lookup_node(args[5])._.full_path_str
      @target.emit_association(:NOT_IMPLEMENTED, *args)
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
