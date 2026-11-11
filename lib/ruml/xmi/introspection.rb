# frozen_string_literal: true

module RUML
  module XMI
    # This is suitiable for UML bootstrapping from XMI.
    class Introspection
      def initialize
        @module_path_name = Hash.new{|h, k| h[k] = k.split('::').freeze}
      end

      def get_class obj
        obj.__class__ rescue obj.class
      end

      def type_of? obj, type
        cls = get_class(obj)
        # puts "type_of?(obj=#{obj}, type=#{type}) : #{obj._xmi.type_name.inspect} #{cls}"
        # binding.pry
        return true if cls.__id__ == type.__id__
        cls_name = cls.name
        type = type.to_s
        return true if cls_name == type
        return true if @module_path_name[cls_name].last == type
        false
      end

      def get_object_id(obj)
        obj._xmi.object_id
      end
      def get_module(elem)
        elem._xmi.namespace
      end
      def set_namespace(elem, namespace)
        elem._xmi.namespace = namespace
      end
      def namespaced_name elem
        namespaces(elem.namespace).map{|x| x.name.to_s}.join("::") + "::" + elem.name
      end
      def namespaces ns
        result = []
        while ns
          result.push(ns)
          ns = ns.namespace
        end
        result.reverse!
        result
      end

      def get_package(elem)
        elem._xmi.package
      end
      def set_package(elem, package)
        elem._xmi.package = package
      end
      def associations elem
        elem._xmi.associations.each do | name, objs |
          objs.each do | obj |
            yield name, obj
          end
        end
      end

      def recur_associations elem, target, sel
        associations(elem) do | name, obj |
          target.send(sel, obj)
        end
      end

      def import_package target, source
        source.packagedElement&.each do | e |
          import_package_element(target, e)
        end
      end

      def import_package_element(target, source)
        log { "import #{e._xmi.type} #{e.name} -> #{target._xmi.type} #{target.name}"}
        target._xmi.imports.push(source)
      end

      def get_imports package
        package._xmi.imports
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
        get_imports(package)&.each do | e |
          return e if e.name == name
        end
        nil
      end

      def find_packagedElement_parent(package, name)
        while package
          if e = find_element(package, name)
            return e
          end
          package = get_package(package)
        end
        nil
      end

      def find_element_parent(package, name)
        while package
          if e = find_element(package, name)
            return e
          end
          package = get_module(package)
        end
        nil
      end

      def log msg=nil
        if @verbose
          msg ||= yield
          $stderr.puts "### #{self.class.name} : #{msg}"
        end
      end
    end
  end
end
