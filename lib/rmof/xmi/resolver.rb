# frozen_string_literal: true
require 'rmof/xmi'

module RMOF
  module XMI
    class Resolver
      def call elem
        @root = elem

        @seen = {}
        @namespace_stack = []
        resolve_namespace(@root)

        @seen = {}
        @package_stack = []
        resolve_packages(@root)

        @seen = {}
        @package_stack = []
        import_packages(@root)

        @root
      end

      def find_element(package, name)
        find_packagedElement(package, name) || find_importedElement(package, name)
      end

      def find_packagedElement(package, name)
        package.packagedElement&.each do | e |
          return e if e.name == name
        end
        nil
      end

      def find_importedElement(package, name)
        package._xmi_imports&.each do | e |
          return e if e.name == name
        end
        nil
      end

      def find_packagedElement_parent(package, name)
        while package
          if e = find_element(package, name)
            return e
          end
          package = package._xmi_package
        end
        nil
      end

      def find_element_parent(package, name)
        while package
          if e = find_element(package, name)
            return e
          end
          package = package._xmi_namespace
        end
        nil
      end

      def unseen elem
        return if @seen[elem.__id__]
        @seen[elem.__id__] = elem
        yield elem
      end

      def associations elem
        elem._xmi_associations.each do | name, objs |
          objs.each do | obj |
            yield name, obj
          end
        end
      end

      def recur_associations sel, elem
        associations(elem) do | name, obj |
          send(sel, obj)
        end
      end

      ###############################

      def resolve_namespace(elem)
        unseen elem do
          namespace = @namespace_stack[-1]
          log { "resolve_namespace #{elem} -> #{namespace}"}
          elem._xmi_namespace = namespace
          case elem._xmi_type
          when "uml:Package", "uml:Class"
            @namespace_stack.push(elem)
            recur_associations(:resolve_namespace, elem)
            @namespace_stack.pop
          else
            recur_associations(:resolve_namespace, elem)
          end
        end
      end

      def resolve_packages(elem)
        unseen elem do
          package = @package_stack[-1]
          log { "resolve_packages #{elem} -> #{package}"}
          elem._xmi_package = package
          case elem._xmi_type
          when "uml:Package"
            @package_stack.push(elem)
            recur_associations(:resolve_packages, elem)
            @package_stack.pop
          else
            recur_associations(:resolve_packages, elem)
          end
        end
      end

      def import_packages(elem)
        unseen elem do
          package = @package_stack[-1]
          case elem._xmi_type
          when "uml:Package"
            # log { "import_packages #{elem}"}
            @package_stack.push(elem)
            elem.packageImport&.each do | import |
              if package = find_element(elem, import.importedPackage)
                import_package(elem, package)
              else
                log { "packageImport : not found for #{import.importedPackage}"}
              end
            end
            @package_stack.pop
          else
            recur_associations(:import_packages, elem)
          end
        end
      end

      def import_package target, source
        source.packagedElement&.each do | e |
          log { "import #{e._xmi_type} #{e.name} -> #{target._xmi_type} #{target.name}"}
          target._xmi_imports.push(e)
        end
      end

      def namespaced_name elem
        namespaces(elem).join("::") + "::" + elem.name
      end

      def namespaces elem
        result = []
        ns = elem.namespace
        while ns
          result.push(ns.name)
          ns = ns.namespace
        end
        result.reverse!
        result
      end

      def log msg=nil
        msg ||= yield
        $stderr.puts "### #{self.class.name} : #{msg}"
      end
    end

    class Formatter
      def initialize out=$stdout
        @out = out
        @depth = 0
        @seen = {}
      end

      def call(obj)
        emit(obj)
      end

      def emit(obj)
        return unless emit_basic(obj)
        # binding.pry if @depth > 10
        obj._xmi_associations.each do | name, objs |
          objs.each do | obj |
            @depth += 1
            indent
            write name
            write " "
            emit(obj)
            @depth -= 1
          end
          binding.pry if name == "defaultValue" && !obj.value.nil?
        end
      end

      def emit_basic(obj)
        # BasicObject does not have a #class method.
        cls = obj._xmi_class
        id = "#{obj.__id__}:#{id.inspect}"
        if @seen[obj.__id__]
          write "#{cls.name} @#{id}\n"
          return false
        end
        @seen[obj.__id__] = obj
        write "#{cls._xmi_type} \##{id} "
        obj._xmi_properties.each do | name, value |
          write "#{name}=#{value.inspect} "
        end
        write "\n"
        true
      end

      def indent
        @out.write "  " * @depth
      end
      def write(s)
        @out.write s
      end
    end

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
            emit_element_begin elem, "module #{elem.name}"
            recur_associations(:emit_module, elem)
            emit_module_end elem
          when "uml:Class"
            emit_module_begin elem
            emit "# #{module_name(elem)}"
            emit_element_begin elem, "class #{elem.name}"
            elem.generalization&.each do | gen |
              @generalizations.push([elem, gen])
              emit "# include #{gen.general}::XMI_Behavior # Generalization"
            end
            emit_begin "module XMI_Behavior"
            recur_associations(:emit_module, elem)
            emit_end
            emit "include XMI_Behavior"
            emit_module_end elem
          when "uml:Property"
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

      def emit_module_end elem
        emit_end
        @module_stack.pop
      end

      def emit_element_begin elem, x=nil
        emit ""
        emit "# Type: #{elem._xmi_type_name}"
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
        @generalizations.each do | (target, gen) |
          gen_mod = find_packagedElement_parent(target._xmi_module, gen.general)
          binding.pry unless gen_mod
          target_name = module_name(target)
          gen_name = module_name(gen_mod)
          emit ""
          emit "# Generalization:"
          emit "# #{gen_name}"
          emit "#{module_name(target)}.include(#{gen_name}::XMI_Behavior)"
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
          indent; puts x
        end
        @indent += 1
      end

      def emit_end
        @indent -= 1
        indent; puts "end"
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
