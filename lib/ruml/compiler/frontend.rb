# frozen_string_literal: true

require 'ruml'
require 'ruml/compiler'
require 'ruml/core/runtime'
require 'ruml/support/logging'
require 'ruml/support/misc'
require 'ruml/compiler/ast'
require 'ruml/compiler/target/ruby'
require 'ruml/compiler/native'
require 'ruml/core/navigation'

module RUML
  module Compiler
  class Frontend
    class Error < CompilerError ; end
    Navigation = RUML::Core::Navigation

    include RUML::Support::Logging::Basic
    EMPTY_ARRAY = [ ].freeze unless defined? EMPTY_ARRAY

    attr_reader :root, :pass
    attr_accessor :target, :target, :file, :code

    def initialize opts = nil, &blk
      opts ||= { } # EMPTY_HASH
      @opts = opts
      @code = nil
      @created_modules = [ ]
      @navigator = RUML::Core::Navigation::Navigator.new
      @native = RUML::Compiler::Native.new
      @file = @opts[:file]
      @root = opts.fetch(:root)
      @target = opts.fetch(:target)
      @target = RUML::Compiler::Target.const_get(@target) if ::Symbol === @target
      @target = @target.new unless RUML::Compiler::Target === @target
      @target.frontend = self
      @current = nil
      @current_stack = [ ]
      @pass = 1
    end

    def run node
      @target.emit_preamble(node)
      @target.emit_root(node) do
        compile(node)
      end
      @target.emit_postamble(node)
      @code = @target.to_s
      save_code()
    end

    def save_code()
      root_name = @root
      root_name = @root.to_s if Module === root_name
      # root_name = @navigator.namespace_str(@native[@root]) unless String === root_name
      root_file_name = root_name.gsub(/::/, '-').downcase
      root_file_name = "tmp/#{root_file_name}.rb"
      # binding.pry
      @file ||= root_file_name
      if @file
        RUML::Support::Misc.write_readonly_file(@file, code)
        $stderr.puts("#{self.class} : wrote #{@file}")
      end
      self
    end

    def eval_code()
      if @file
        $stderr.puts("#{self.class} : loading #{@file}")
        load(file)
      else
        ::Kernel.eval(code)
      end
      self
    end

    def compile node
      metatype = node._.metatype
      sels = [ :"compile_#{metatype}_#{pass}", :"compile_#{metatype}" ]
      # sels = [ :"compile_#{metatype}_#{pass}" ]
      sels.each do | sel |
        if respond_to?(sel)
          # @target.trace! "'compile : #{sel} : #{node.inspect}}'"
          log { "#{sel.inspect} : #{node.inspect}" }
          return send(sel, node)
        end
      end
      log { "no handler : #{node._}" }
      # binding.pry
      _compile_ownedElement(node)
    end

    def compile_Root_1 node
      @pass = 1
      node.ownedElement.each {|x| compile(x) }
      @pass = 2
      node.ownedElement.each {|x| compile(x) }
    end

    def compile_Class node
      send("compile_Namespace_#{pass}", node)
    end

    def compile_Package node
      node._.superClass_remaining ||= []
      send("compile_Namespace_#{pass}", node)
    end

    def compile_Namespace_1 node
      path = Navigation.namespace_path(node)
      path_str = Navigation.namespace_str(node)
      node._.to_h.update(
        path: path,
        path_str: path_str,
      )
      log { "#{path_str} { " }

      @target.emit_namespace(node)

      _compile_ownedElement(node)

      log { "}" }
    end

    def compile_Namespace_2 node
      _compile_ownedElement node
      _compile_children node, :stereotype, :import
      _compile_generalization_2 node
      _compile_children node, :property, :association, :method, :constant
      # _compile_enumeration node
    end

    def _compile_generalization_2 node
      @target.emit_generalization(node)
    end

    def compile_Operation_2 node
      @target.emit_operation(node)
    end

    def compile_Constant_2 node
      @target.emit_constant(node)
    end

    def compile_Import_2 node
      @target.emit_import(node)
    end

    def compile_Stereotype_2 node
      args = node._.args
    end

    ######################################################

    def walk node, &blk
      t = RUML::Support::Traverser.new
      t.traversing do
        walk_node node, t, &blk
      end
    end

    def walk_node node, t, &blk
      t.traverse(node) do
        yield node
        node.ownedElement&.each do | e |
          walk_node(e, t, &blk)
        end
      end
    end

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
