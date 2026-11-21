# frozen_string_literal: true

require 'ruml/core'
require 'ruml/core/navigation'

module RUML::Core
  class Factory
    def initialize root
      @root = root
      @root_module = {}
      @class_module = {}
      @instance_by_id = {}
    end

    def new ns, name, props, id = nil
      if id && (instance = @instance_by_id[id])
        return instance
      end
      instance = class_module(ns, name).new(props)
      @instance_by_id[id] = instance if id
      instance
    end

    def class_module ns, name
      ns = ns.to_sym
      name = name.to_s
      @class_module[[ns, name]] ||= lookup(root_module(ns), name)
    end

    def root_module ns
      name = ns.to_s.upcase.to_sym
      @root_module[ns] ||= @root.const_get(name)
    end

    def lookup base, name
      path = RUML::Core::Navigation.split_path(name)
      path.inject(base) do | mod, name |
        name = name.to_sym
        mod.const_get(name)
      end
    end
  end
end
