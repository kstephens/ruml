# frozen_string_literal: true

require 'ruml/boot'
require 'ruml/compiler/ast'

module RUML::Boot
  class Factory
    def initialize root=nil
      @root = root
      @instance_by_id = {}
    end

    def new ns, type, props, id = nil
      if id && (instance = @instance_by_id[id])
        return instance
      end
      instance = RUML::Compiler::AST::Node.new(props)
      instance._.metatype = type
      instance._.ns = ns
      instance._.instance_id = id
      instance._.ruby_module_root = @root
      @instance_by_id[id] = instance if id
      instance
    end
  end
end
