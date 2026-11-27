# frozen_string_literal: true

require 'ruml/boot'
require 'ruml/core/factory'
require 'ruml/compiler/ast'

module RUML::Boot
  class Factory < RUML::Core::Factory
    # !!! remove unused
    def initialize root: nil
      super(root: root)
    end

    # rename create()
    def make_instance ns, type, props, id
      instance = super(ns, type, props, id)
      instance._.metatype = type
      # !!! remove.
      # instance._.ns = ns
      # instance._.instance_id = id
      # instance._.ruby_module_root = @root
      instance
    end

    def class_module _ns, type
      return type if ::Class === type
      RUML::Compiler::AST::Node
    end
  end
end
