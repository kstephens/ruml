# frozen_string_literal: true
require 'rmof/xmi/resolver'

module RMOF
  module XMI
    class Compiler < Resolver
      def initialize out=$stdout
        @out = out
      end

      def call elem
        @root = elem
        @depth = 0
        @indent = 0
        @indent_comment = 0

        emit_header "Packages, Classes"
        @seen = {}
        @module_stack = []
        @modules = []
        @generalizations = []
        @classes = {}
        emit_module(@root)

        emit_header "PackageImports"
        @seen = {}
        @module_stack = []
        emit_imports(@root)

        emit_header "Generalization"
        @seen = {}
        @module_stack = []
        emit_includes(@root)

        nil
      end

      def emit_module elem
        unseen elem do
          parent = @module_stack[-1]
          case elem._xmi_type
          when "uml:Package"
            emit_module_begin elem
            emit "# #{module_name(elem)}"
            emit_element_begin elem, "module #{elem.name}"
            recur_associations(:emit_module, elem)
            emit_module_end elem, "module #{elem.name}"
          when "uml:Class"
            emit_module_begin elem
            emit "# #{module_name(elem)}"
            emit_element_begin elem, "class #{elem.name} < ::RMOF::BaseClass"
            elem.generalization&.each do | gen |
              @generalizations.push([elem, gen])
              emit "# include #{gen.general}::XMI_Behavior # Generalization"
            end
            emit_begin "module XMI_Behavior"
            recur_associations(:emit_module, elem)
            emit_end
            emit "include XMI_Behavior"
            emit_module_end elem, "class #{elem.name}"
          when "uml:Property"
            # emit "# #{namespaced_name(elem)}"
            emit_element_begin elem
            emit "# Type: #{elem.type}"
            elem.defaultValue&.each do |x|
              emit "# Default: #{x._xmi_type}: #{x.value.inspect}"
            end
            emit "attr_accessor :#{elem.name}"
          else
            recur_associations(:emit_module, elem)
          end
        end
      end

      def emit_module_begin elem
        parent = @module_stack[-1]
        elem._xmi_module = parent
        elem._xmi_module_name = module_name(elem)
        parent._xmi_modules[elem.name] = elem if parent
        @module_stack.push(elem)
        @modules.push(elem)
      end

      def emit_module_end elem, x=nil
        emit_end x
        @module_stack.pop
      end

      def emit_element_begin elem, x=nil
        emit ""
        emit "# Type: #{elem._xmi_type_name}"
        emit "# Instance: #{elem._xmi_object_id}"
        comments(elem)
        comment_properties(elem)
        emit_begin x unless x.nil?
      end

      def emit_imports elem
        unseen elem do
          case elem._xmi_type
          when "uml:Package"
            target = elem
            @module_stack.push(elem)
            target_name = module_name(target)
            binding.pry if target_name.empty?
            elem._xmi_imports&.each do | import |
              next unless import._xmi_module
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
        unseen elem do
          @generalizations.each do | (target, gen) |
            gen_mod = find_packagedElement_parent(target._xmi_module, gen.general)
            binding.pry unless gen_mod
            target_name = module_name(target)
            gen_name = module_name(gen_mod)
            emit ""
            emit "# Generalization:"
            emit "# #{gen_name}"
            emit "#{module_name(target)}::XMI_Behavior.include(#{gen_name}::XMI_Behavior)"
          end
        end
      end

      def find_module elem, name
        while elem
          mod = elem._xmi_modules[name]
          return mod if mod
          elem = elem._xmi_module
        end
      end

      def module_path elem
        mods = []
        while elem
          mods.push elem.name
          elem = elem._xmi_module
        end
        mods.reverse!
        mods
      end

      def module_name elem
        module_path(elem).join('::')
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
        emit "# Properties:"
        @indent_comment += 1
        format_properties(elem).each{| p | emit_comment p}
        @indent_comment -= 1
      end

      def format_properties elem
        elem._xmi_properties&.map{| name, value | "#{name}=#{value.inspect}"}
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
    end
  end
end

