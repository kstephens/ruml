# frozen_string_literal: true

require 'ruml/support/context'
require 'ruml/support/basic_object'
require 'ruml/core/navigation'

module RUML
  module Support
    module AST

    class Node < Support::BasicObject::Base
      def _ ; @_ ||= Meta.new({node: self}) ; end
      Support.copy_method(self, :eql?, ::Object)
      Support.copy_method(self, :is_a?, ::Object)
      def _desc_; "#{_._desc_} #{@_repr.keys}"; end
    end

    class Meta < Support::BasicObject::Base
      include ::RUML::Core::Navigation
      Support.copy_method(self, :eql?, ::Object)
      Support.copy_method(self, :is_a?, ::Object)

      ATTRS = %i[meta name args].freeze

      def _desc_
        @_desc_ ||= ATTRS.map do |name|
          "#{name}=#{_repr[name].inspect}"
        end.join(' ').freeze
      end

      def to_s
        "#{node._.meta} #{args.map(&:inspect).join(", ")}"
      end

      def node_keys
        node._repr.keys
      end

      def args_named(args, *names)
        args.zip(names) do | (arg, name)|
          node[name] = arg
        end
      end

      def args_opts(args)
        opts = args[-1]
        if ::Hash === opts
          @_repr.update(opts)
        end
      end

    end
  end
end
