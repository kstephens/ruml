# frozen_string_literal: true

require 'ruml/support/context'
require 'ruml/support/basic_object'

module RUML
  module Compiler
    module AST
      class Node < Support::BasicObject::Base
        def _ ; @_ ||= Support::BasicObject::Base.new({node: self}) ; end
        Support.copy_method(self, :eql?, ::Object)
        def _desc_; "#{_._desc_} #{@_repr.keys}"; end
        def << x
          @content << x
        end
        def to_s
          content.map(&:to_s).join("")
        end
      end
      class File < Node
      end
      class Namespace < Node
      end
      class Module < Namespace
      end
      class Class < Module
      end
      class Constant < Node
        attr_reader :name, :value
      end
      class Method < Namespace
      end
    end
  end
end
