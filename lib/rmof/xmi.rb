# frozen_string_literal: true
require 'rmof'

module RMOF
  class XXMI
    attr_accessor :root

    def initialize
      @factory = Factory.new
      @root = @factory.get_xmi_type("xmi", "XMI").new
    end

    def load(xmi_file)
      File.open(xmi_file) do |f|
        Nokogiri::XML(f) do |config|
          config.noblanks
        end
      end
    end

    def call(xmi_file)
      env = Environment.new
      @dom = load(xmi_file)
      @hrefs = {
        # "http://www.omg.org/spec/UML/20131001/PrimitiveTypes.xmi#String": ::String,
        # "http://www.omg.org/spec/UML/20131001/PrimitiveTypes.xmi#Integer": ::Integer,
        # "http://www.omg.org/spec/UML/20131001/PrimitiveTypes.xmi#Boolean": Boolean,
      }
      env.target_stack.push(@root)
      # binding.pry
      @phase = :build
      parse_doc(@dom, env)
      @phase = :resolve
      parse_doc(@dom, env)
      self
    end

    def parse_doc(elem, env)
      elem.children[0].children.each do | e |
        next if e.name == "documentation"
        parse(e, env)
      end
    end

    def parse_children(elem, env)
      elem.children.each do |e|
        parse(e, env)
      end
    end

    def parse(elem, env)
      log { "### ######################################################" }
      log { "ELEM  : #{elem.name} @#{elem.object_id}" }
      log { "ATTRS : #{convert_attrs(elem).inspect}" }
      parent = env.target
      env.elem_stack.push(elem)
      begin
        xmi_type = get_attr(elem, 'xmi', 'type')&.value
        xmi_id = get_attr(elem, 'xmi', 'id')&.value
        xmi_idref = get_attr(elem, 'xmi', 'idref')&.value
        href = get_attr(elem, nil, 'href')&.value
        case
        when xmi_idref
          if xmi_type || xmi_id
            raise StandardError, "has idref #{xmi_idref.inspect} and xmi_type #{xmi_type.inspect} xmi_id #{xmi_id.inspect}"
          end
          obj = env.xmi_id_to_object[xmi_idref]
          case
          when @phase == :resolve
            unless obj
              raise StandardError, "unknown idref #{xmi_idref.inspect}"
            end
          end
        when xmi_type
          # binding.pry
          xmi_type_prefix, xmi_type_name = xmi_type.split(':', 2)
          properties = {}
          get_attr(elem, nil, nil) do | attr |
            properties[attr.name] = attr.value
          end
          obj = @factory.make_instance(xmi_type_prefix, xmi_type_name, properties)
          obj._xmi_type = xmi_type
          obj._xmi_id = xmi_id
          obj._xmi_type_prefix = xmi_type_prefix
          obj._xmi_type_name = xmi_type_name
          env.xmi_id_to_object[xmi_id] = obj if xmi_id
          log { "PROPERTIES : #{properties.inspect}" }
          log { "OBJECT     : #{obj.inspect}" }
        when href
          unless obj = @hrefs[href]
            obj = @factory.get_xmi_type("xmi", "HREF").new
            obj.href = href
          end
        when elem.attributes.empty?
          parent.__send__(:"#{elem.name}=", elem.content)
        else
          raise StandardError, "no xmi:type or xmi:idref"
        end

        if obj
          env.target_stack.push(obj)
          begin
            if @phase == :resolve and obj and parent
              log { "  obj=#{obj}" }
              log { "  parent=#{parent}" }
              key = elem.name.to_sym
              parent._xmi_associations[key].push(obj)
              log { "  associations: #{parent._xmi_associations.keys.inspect}" }
            end
            parse_children(elem, env)
          ensure
            env.target_stack.pop
          end
        end

      ensure
        env.elem_stack.pop
      end
    end

    def convert_attrs(elem)
      attrs = {}
      elem.attribute_nodes.each do | attr |
        name = attr.name
        if prefix = attr.namespace&.prefix
          name = "#{prefix}:#{name}"
        end
        attrs[name] = attr.value
      end
      attrs
    end

    def get_attr(elem, prefix, name)
      elem.attribute_nodes.each do | attr |
        next if name && name != attr.name
        next if prefix.nil? && attr.namespace&.prefix
        next if prefix && prefix != attr.namespace&.prefix
        if block_given?
          yield attr
        else
          return attr
        end
      end
      nil
    end

    def log msg=nil
      if @verbose
        msg ||= yield
        $stderr.put "### #{msg}"
      end
    end

    class Environment
      attr_reader :elem_stack, :target_stack, :xmi_id_to_object
      attr_reader :root

      def initialize
        @elem_stack = []
        @target_stack = []
        @xmi_id_to_object = {}
      end

      def elem; @elem.stack[-1]; end
      def target; @target_stack[-1]; end
    end

    class Factory
      def initialize
        @namespaces = {}
        @object_id = 0
      end

      def make_instance(namespace, name, properties)
        cls = get_xmi_type(namespace, name)
        obj = cls.new
        obj._xmi_type = "#{namespace}:#{name}"
        properties.each do | name, value |
          obj.__send__(:"#{name}=", value)
        end
        obj._xmi_object_id = (@object_id += 1)
        obj
      end

      def get_xmi_namespace(name)
        if result = @namespaces[name]
          result
        end
        @namespaces[name] = Namespaces.const_get(:"N_#{name}", false)
      end

      def get_xmi_type(ns, name)
        ns = ns.to_sym
        name_sym = name.to_sym
        mod = get_xmi_namespace(ns)
        return mod.const_get(name_sym, false) if mod.const_defined?(name_sym, false)
        cls = ::Class.new(Base)
        cls.extend(BaseAttributes)
        mod.const_set(name_sym, cls)
        cls._xmi_initialize_BaseAttributes
        cls
      end

    end

    module Namespaces
      module N_xmi; end
      module N_uml; end
      module N_mof; end
      module N_mofext; end
    end

    module BaseAttributes
      attr_reader :_xmi_properties, :_xmi_associations
      attr_accessor :_xmi_object_id, :_xmi_id
      attr_accessor :_xmi_type, :_xmi_type_prefix, :_xmi_type_name
      attr_accessor :_xmi_package, :_xmi_namespace
      attr_accessor :_xmi_module, :_xmi_module_name, :_xmi_modules
      attr_accessor :_xmi_imports
      @@_xmi_object_id = 0

      def _xmi_initialize_BaseAttributes
        @_xmi_properties = {}
        @_xmi_associations = ::Hash.new{|h, k| h[k] = []}
        @_xmi_operations = {}
        @_xmi_modules = {}
        @_xmi_imports = []
        # @_xmi_object_id = (@@_xmi_object_id += 1)
      end

      def _xmi_class
        # BasicObject does not have a #class method.
        (class << self; self; end).superclass
      end

      def method_missing sel, *args, &blk
        case
        when blk
          raise ::StandardError, "#{sel}: block given"
        when args.empty?
          if @_xmi_associations.key?(sel)
            @_xmi_associations[sel]
          else
            @_xmi_properties[sel]
          end
        when (name = sel.to_s) && name[-1] == "=" && args.size == 1
          name = name[0..-2].to_sym
          if @_xmi_associations.key?(name)
            @_xmi_associations[name] = [ args[0] ]
          else
            @_xmi_properties[name] = args[0]
          end
        else
          # $stderr.puts "sel=#{sel.inspect} args=#{args.inspect}"
          @_xmi_operations[sel].call(*args)
        end
      end
    end

    class Base < ::BasicObject
      include BaseAttributes

      def initialize
        _xmi_initialize_BaseAttributes
      end

      def inspect
        cls = _xmi_class
        id = "#{__id__}:#{@_xmi_object_id.inspect}"
        "#<#{cls&.name} #{id} #{@_xmi_properties.inspect}>"
      end

      def to_s
        cls = _xmi_class
        id = "#{__id__}:#{@_xmi_object_id.inspect}"
        "#<#{cls&.name} #{id} />"
      end
    end

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

      def x_namespaces elem, result = []
        if elem.namespace
          result.push(elem)
          namespaces(elem.namespace, result)
        end
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
