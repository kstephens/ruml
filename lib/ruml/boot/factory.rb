# frozen_string_literal: true

require 'ruml/boot'

module RUML::Boot
  class Factory
    def initialize root
      @root = root
      @root_module = Hash.new do | h, k |
        h[k] = @root.const_get(k.to_s.upcase.to_sym)
      end
      @class_module = Hash.new do | h, k |
        ns, name = k
        h[k] = root_module(ns).const_get(name)
      end
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
      @class_module[[ns, name]]
    end

    def root_module ns
      ns = ns.to_sym
      @root_module[ns]
    end
  end
end
