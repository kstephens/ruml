# frozen_string_literal: true

require 'ruml/core/runtime'


module RUML::Core
  module Navigation
    module Navigated; end
    extend self

    def for_ancestors node
      while node
        yield node
        raise "for_ancestors: loop detected: #{node.inspect}" if node == node.owner
        node = node.owner
      end
    end
    def namespace_path node
      result = []
      for_ancestors(node) do | node |
        result << node if node && node != ""
      end
      result.reverse!
    end

    def namespace_str(node)
      join_path(namespace_path(node).map(&:name))
    end
    alias_method :path_str, :namespace_str

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
        namespace_path(node)
      end
    end

    def root_node node # -> Node
      while node.owner
        raise "root_node: loop detected: #{node.inspect}" if node == node.owner
        node = node.owner
      end
      node
    end

    def node_ancestors node
      result = []
      for_ancestors(node) {|node| result << node}
      result.reverse!
    end

    def ownedElement_by_name node, name
      # binding.pry unless ::String === name
      raise unless ::String === name
      node.ownedElement&.find{|c| c.name == name}
    end

    def importedElement_by_name node, name
      raise unless ::String === name
      node.importedPackage&.each do | ns |
        if (found = ownedElement_by_name(ns, name))
          return found
        end
      end
    end

    def find_node node, path # -> Node
      path = split_path(path)
      # pp(args: args, name: path)
      if path[0] == ""
        node = root_node(node)
        path = path[1...-1]
      end
      path.inject(node) do | node, name |
        name = name.name unless ::String === name
        binding.pry if ::Array === node
        found = ownedElement_by_name(node, name)
        found ||= importedElement_by_name(node, name) # !!! kinda
        return nil unless found
        found
      end
    end

    def find_node_scoped node, path
      path = split_path(path)
      # seen = Set.new
      for_ancestors(node) do | node |
        if (found = find_node(node, path))
          return found
        end
      end
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
          names.concat(x.to_s.split("::"))
        when ::Array
          queue.unshift(x)
        when Navigated
          # ??? should this be names = namespace_path(x) since it's rooted?
          names.concat(namespace_path(x))
        else
          names.push(x.name)
          # if x.respond_to?(:name)
          #   names.push(x.name)
          # else
          #   __raise__ ::ArgumentError, "convert_to_name_path : unexpected #{x.inspect}"
          # end
        end
      end
      names
    end

    class Navigator
      include Navigation
      def self.cache *meths
        meths.each do | meth |
          class_eval(<<"RUBY")
def #{meth}(node, *args)
  (_value_ = @_#{meth}_ ||= {})[node.__id__] ||= super(node, *args)
end
RUBY
        end
      end
      cache :namespace_path, :namespace_str, :root_node, :node_ancestors
    end
  end
end
