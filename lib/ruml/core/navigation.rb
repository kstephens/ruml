# frozen_string_literal: true

require 'ruml/core/runtime'
require 'ruml/support/misc'


module RUML::Core
  # !!! these methods are repeated elsewhere.
  # should this be integrated into an "introspection" 
  # module with Factory?  
  # Perhaps integrated with Runtime::Meta?
  # rename this to Introspection?
  # Should it reuse/integrate MOF::Introspection?
  module Navigation
    class NavigationError < RUML::Error; end

    # !!! is this used?
    module Navigated; end
    extend self

    # !!! change this to an Enumerator:
    def for_ancestors node
      while node
        yield node
        raise "for_ancestors: loop detected: #{node.inspect}" if node == node.owner
        # !!! parameterize this to follow any "parent" attr.
        node = node.owner
      end
    end
    def ancestors node
      result = []
      for_ancestors(node) do | node |
        result << node
      end
      result.reverse!
    end
    # !!! remove theses and fix references:
    alias :ancestors_path :ancestors
    alias :namespace_path :ancestors

    def path_str(node)
      join_path(ancestors_path(node).map(&:name))
    end
    # !!! remove and fix references:
    alias_method :namespace_str, :path_str

    def join_path(names)
      names.compact.map(&:to_s).reject(&:empty?).join("::")
    end

    def split_path(node)
      case node
      when ::Array
        node
      when ::String
        node.split("::", -1).reject(&:empty?)
      else
        ancestors_path(node)
      end
    end

    # !!! reuse ancestors?
    # parameterizr node.owner.
    def root_node node # -> Node
      while node.owner
        raise "root_node: loop detected: #{node.inspect}" if node == node.owner
        node = node.owner
      end
      node
    end

    # !!! same as ancestors(node).to_a.reverse!
    def node_ancestors node
      result = []
      for_ancestors(node) {|node| result << node}
      result.reverse!
    end
    
    # !!! parameterize
    def ownedElement_by_name node, name
      raise unless ::String === name
      node.ownedElement&.find{|c| c.name == name}
    end

    def importedElement_by_name node, name
      raise unless ::String === name
      node.importedPackage ||= RUML::Core::Misc::UniqueArray.new
      # node.importedPackage.map! do |pkg|
      #   # pkg = find_node_scoped(node, pkg, imports: false) if String === pkg
      #   pkg
      # end
      node.packageImport&.each do |import|
        package = import.importedPackage
        binding.pry unless package
        unless ::String === package
          return node if (node = ownedElement_by_name(package, name))
        end
      end
      nil
    end

    def find_node node, path, imports=true # -> Node
      path = split_path(path)
      # pp(args: args, name: path)
      if path[0] == ""
        node = root_node(node)
        path = path[1...-1]
      end
      path.inject(node) do | node, name |
        name = name.name unless ::String === name
        # !!! delete this:
        binding.pry if ::Array === node
        # !!! refactor these two into a single method:
        found = ownedElement_by_name(node, name)
        found ||= importedElement_by_name(node, name) if imports # !!! kinda
        # !!! remove this
        binding.pry if ::Array === found
        return nil unless found
        found
      end
    end

    def find_node_scoped node, path, imports=true
      path = split_path(path)
      # !!! delete me.
      # seen = Set.new
      for_ancestors(node) do | ancestor |
        if (found = find_node(ancestor, path, imports))
          return found
        end
      end
    end

    def find_node_or_die(node, name, msg=nil, &blk)
      return node if node.to_s == name
      # !!! delete:
      binding.pry unless find_node_scoped(node, name)
      RUML::Support::Misc.or_die(find_node_scoped(node, name), NavigationError,
          "#{msg} : cannot find #{name.inspect} in #{namespace_str(node)}", &blk)
    end


    def convert_to_name_path x
      case x
      when ::String, ::Symbol
        queue = [x]
      else
        queue = x.dup
      end
      names = []
      while (x = queue.shift)
        case x
        when nil
          nil
        when ::String, ::Symbol
          # !!! reuse split_path.
          names.concat(x.to_s.split("::"))
        # !!! use Enumerable
        when ::Array
          queue.unshift(x)
        # !!! is this used?
        when Navigated
          # ??? should this be names = namespace_path(x) since it's rooted?
          names.concat(namespace_path(x))
        else
          names.push(x.name)
          # !!! delete:
          # if x.respond_to?(:name)
          #   names.push(x.name)
          # else
          #   __raise__ ::ArgumentError, "convert_to_name_path : unexpected #{x.inspect}"
          # end
        end
      end
      names
    end
    
    # !!! these are introspections NOT navigations.
    def isClass? node
      # !!! can we avoid _ with an Introspection object?
      
      node._.metatype == :Class # rescue false
    end

    def isPrimitive? node
      hasStereotype?(node, :primitive)
    end

    def isPrimitiveType? type
      result = false
      result ||= isNativeModule?(type)
      result ||= isPrimitive?(type)
      result ||= namespace_str(type) =~ /\ARUML::Core::PrimitiveType/
      result
    end

    def native_module type
      return type if ::Module === type
      type.__ruml_obj__ if ::RUML::Compiler::Native::RNamespace === type
    end

    alias :isNativeModule? :native_module

    def native_path_or node
      native = native_module(node)
      return native.to_s if native
      path_str(node)
    end

    def hasStereotype? node, name
      name = name.to_s
      node&.stereotype&.find{|x| x.name == name}
    end

    # !!! delete if we refactor into an Introspector.
    class Navigator
      include Navigation
      # !!! are these worth or safe to cache?
      # premature optimization.
      # delete this, we can revive it.
      def self.cache *meths
        meths.each do | meth |
          class_eval(<<"RUBY")
def #{meth}(node, *args)
  (_value_ = @_#{meth}_ ||= {})[node.__id__] ||= super(node, *args)
end
RUBY
        end
      end
      # cache :ancestors, :path_str, :root_node
    end
  end
end
