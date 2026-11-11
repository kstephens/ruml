# frozen_string_literal: true

require 'rmof/xmi/resolver'
require 'ruml/traverser'
require 'method_source'

module RMOF
  module XMI
    class Compiler
      include RUML::TraverserMethods
      attr_accessor :resolver

      def initialize out=$stdout
        @out = out
        @i = Introspection.new
        @verbose = true
      end

      def call elem
        @root = elem
        @indent = 0
        @indent_comment = 0

        emit <<-EOF
require 'ruml/loadtime'
        EOF
        traversing :emit_module do
          emit_header "Packages, Classes"
          @module_stack = []
          @generalizations = []
          emit_module(@root)
        end

        traversing :emit_imports do
          emit_header "PackageImports"
          @module_stack = []
          emit_imports(@root)
        end

        traversing :emit_includes do
          emit_header "Generalization"
          @module_stack = []
          emit_includes(@root)
        end

        nil
      end

      def recur_associations(sel, elem)
        @i.recur_associations(elem, self, sel)
      end

      def emit_module elem
        traverse elem do
          # binding.pry
          # log elem.inspect
          if @i.type_of?(elem, "Package")
            emit_module_begin elem
            emit "# #{module_name(elem)}"
            emit_element_begin elem, "module #{elem.name}"
            unless @root_package
              @root_package = elem
              emit "RMOF_ = RUML::Loadtime.new(self)"
            end
            recur_associations(:emit_module, elem)
            emit_module_end elem, "module #{elem.name}"
          elsif @i.type_of?(elem, "Class")
            emit_module_begin elem
            emit "# #{module_name(elem)}"
            emit_element_begin elem, "class #{elem.name} < ::RMOF::BaseClass"
            elem.generalization&.each do | gen |
              @generalizations.push([elem, gen])
              emit "# include #{gen.general}::RMOF_Behavior # Generalization"
            end
            emit_begin "module RMOF_Behavior"
            recur_associations(:emit_module, elem)
            emit_end
            emit "include RMOF_Behavior"
            emit_module_end elem, "class #{elem.name}"
          elsif @i.type_of?(elem, "Property")
            # emit "# #{namespaced_name(elem)}"
            emit_element_begin elem
            emit "# Type: #{elem.type.inspect}"
            elem.defaultValue&.each do |x|
              emit "# Default: #{x._xmi.type}: #{x.value.inspect}"
            end
            emit "attr_accessor :#{elem.name}"
            emit "RMOF_.meta(self, :Property, #{elem._xmi.properties})"
          elsif @i.type_of?(elem, "Association")
            emit_element_begin elem
            emit "#{elem.name} = RMOF_.meta(self, :Association, #{elem._xmi.properties.inspect})"
            # emit "#{elem.name} = RMOF.meta(:Association).new.tap do | assoc |"
            # @indent += 1
            # elem.memberEnd&.each do | e |
            #   emit "assoc.memberEnd.push(#{e.name})"
            # end
            # @indent -= 1
            # emit "end"
            emit_end
          else
            recur_associations(:emit_module, elem)
          end
        end
      end

      def emit_module_begin elem
        parent = @module_stack[-1]
        elem._xmi.module = parent
        elem._xmi.module_name = module_name(elem)
        parent._xmi.modules[elem.name] = elem if parent
        @module_stack.push(elem)
      end

      def emit_module_end elem, x=nil
        emit_end x
        @module_stack.pop
      end

      def emit_element_begin elem, x=nil
        emit ""
        emit "# Fullname: #{@i.namespaced_name(elem)}"
        emit "# Type: #{elem._xmi.type_name}"
        emit "# Instance: #{@i.get_object_id(elem)}"
        comments(elem)
        comment_properties(elem)
        emit_begin x unless x.nil?
      end

      def emit_imports elem
        traverse elem do
          # binding.pry
          if @i.type_of?(elem, "Package")
            target = elem
            @module_stack.push(elem)
            target_name = module_name(target)
            binding.pry if target_name.empty?
            elem._xmi.imports&.each do | import |
              next unless import._xmi.module
              import_name = module_name(import)
              emit "#{target_name}::#{import.name} = #{import_name}"
            end
            @module_stack.pop
          else
            recur_associations(:emit_imports, elem)
          end
        end
      end

      def emit_includes elem
        traverse elem do
          @generalizations.each do | (target, gen) |
            gen_mod = @i.find_packagedElement_parent(target._xmi.module, gen.general)
            # binding.pry unless gen_mod
            target_name = module_name(target)
            gen_name = module_name(gen_modd)
            emit ""
            emit "# Generalization:"
            emit "# #{gen_name}"
            emit "#{module_name(target)}::RMOF_Behavior.include(#{gen_name}::RMOF_Behavior)"
          end
        end
      end

      def find_module elem, name
        while elem
          mod = elem._xmi.modules[name]
          return mod if mod
          elem = elem._xmi.module
        end
      end

      def module_name elem
        # binding.pry
        module_path(elem).join('::')
      end

      def module_path elem
        mods = []
        while elem
          mods.push elem.name
          elem = elem._xmi.module
        end
        mods.reverse!
        mods
      end

      def emit_header x
        emit ""
        emit_comment "#############################################################################"
        emit_comment "# #{x}"
      end

      def emit x
        indent
        puts x
      end

      def emit_begin x=nil
        unless x.nil?
          indent
          puts x
        end
        @indent += 1
      end

      def emit_end x=nil
        @indent -= 1
        indent
        puts x.nil? ? "end" : "end # #{x}"
      end

      def comments(elem)
        elem.ownedComment&.each do | comment |
          comment.body.gsub(/\b\. /, ". \n").split("\n").each do | text |
            emit_comment text
          end
        end
      end

      def emit_comment x
        emit "# #{comment_indent}#{x}"
      end

      def comment_properties elem
        props = format_properties(elem)
        unless props.empty?
          emit "# Properties:"
          @indent_comment += 1
          props.each{| p | emit_comment p}
          @indent_comment -= 1
        end
      end

      def format_properties elem
        elem._xmi.properties&.map{| name, value | "#{name}=#{value.inspect}"}
      end

      def write x
        @out.write x.to_s
      end
      def puts x
        @out.puts x.to_s
      end
      def comment_indent
        "  " * @indent_comment
      end
      def indent
        @out.write "  " * @indent
      end

      def log msg=nil
        if @verbose
          msg ||= yield
          $stderr.puts "### #{self.class.name} : #{msg}"
        end
        nil
      end
    end
  end
end
