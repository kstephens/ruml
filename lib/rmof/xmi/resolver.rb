# frozen_string_literal: true

require 'rmof/xmi'
require 'rmof/xmi/introspection'
require 'ruml/traverser'

module RMOF
  module XMI
    class Resolver
      include RUML::Traverser

      def initialize
        @i = Introspection.new
        @package_for = {}
        @verbose = true
      end

      def call elem
        @root = elem

        traversing :resolve_namespace do
          @namespace_stack = []
          resolve_namespace(@root)
        end

        traversing :resolve_packages do
          @package_stack = []
          resolve_packages(@root)
        end

        traversing :import_packages do
          @package_stack = []
          import_packages(@root)
        end

        @root
      end

      def recur_associations(sel, elem)
        @i.recur_associations(elem, self, sel)
      end

      def resolve_namespace(elem)
        traverse elem do
          namespace = @namespace_stack.last
          if elem.name
            log { "resolve_namespace #{elem} #{elem.name} -> #{namespace} #{namespace&.name}"}
            @i.set_namespace(elem, namespace)
            @namespace_stack.push(elem)
            recur_associations(:resolve_namespace, elem)
            @namespace_stack.pop
          else
            recur_associations(:resolve_namespace, elem)
          end
        end
      end

      def resolve_packages(elem)
        traverse elem do
          package = @package_stack.last
          log { "resolve_packages #{elem} -> #{package}"}
          @i.set_package(elem, package)
          @package_for[elem] = package
          if @i.type_of?(elem, "Package")
            @package_stack.push(elem)
            recur_associations(:resolve_packages, elem)
            @package_stack.pop
          else
            recur_associations(:resolve_packages, elem)
          end
        end
      end

      def import_packages(elem)
        traverse elem do
          if @i.type_of?(elem, "Package")
            package = @package_stack.last
            log { "import_packages #{elem}"}
            @package_stack.push(elem)
            elem.packageImport&.each do | import |
              if package = @i.find_element(elem, import.importedPackage)
                log { "import_packages #{elem} <- #{import.importedPackage}"}
                import_package(elem, package)
              else
                log { "WARNING: packageImport : not found for #{import.importedPackage}"}
              end
            end
            @package_stack.pop
          else
            recur_associations(:import_packages, elem)
          end
        end
      end

      def import_package target, source
        @i.import_package target, source
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
