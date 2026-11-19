# frozen_string_literal: true

require 'ruml/core/runtime'


module RUML::Core
  module Navigation
    module Navigated; end

    def namespace_path node
      result = []
      while node
        result << node if node.name
        node = node.owner
      end
      result.reverse!
    end

    def namespace_str(node)
      namespace_path(node).map(&:name).compact.map!(&:to_s).reject(&:empty?).join("::")
    end
    alias_method :path_str, :namespace_str

    def root_node node # -> Node
      while node.owner
        node = node.owner
      end
      node
    end

    def node_ancestors node
      result = []
      while node
        result << node
        node = node.owner
      end
      result.reverse!
    end

    def ownedElement_by_name node, name
      name = name.to_s
      node.ownedElement&.find{|c| c.name == name}
    end

    def find_node node, names # -> Node
      # pp(args: args, name: names)
      if names[0] == ""
        node = root_node(node)
        names = names[1...-1]
      end
      names.inject(node) do | node, name |
        # pp(node: node, name: name)
        found = ownedElement_by_name(node, name)
        return nil unless found
        found
      end
    end

    def find_node_scoped node, ident
      ident = ident.to_s
      while node
        if (found = find_node(node, [ident]))
          return found
        end
        node = node.owner
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
          binding.pry
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
