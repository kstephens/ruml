# frozen_string_literal: true

require 'ruml'
require 'ruml/core'
require 'ruml/core/navigation'
require 'ruml/support/misc'

module RUML::Core
  class Factory
    def initialize root: nil
      @root = root or raise ArgumentError
      @root_module = {}
      @class_module = {}
      @instance_by_id = {}
    end

    def new ns, name, props, id = nil
      if id && (instance = @instance_by_id[id])
        return instance
      end
      # puts("new(#{ns.inspect}, #{name.inspect}) => ...")
      instance = class_module(ns, name).new(props)
      # puts("new(#{ns.inspect}, #{name.inspect}) => #{instance.inspect}")
      # binding.pry
      @instance_by_id[id] = instance if id
      instance
    end

    def class_module ns, name
      ns = ns.to_sym
      name = name.to_s
      @class_module[[ns, name]] ||= lookup_const(root_module(ns), name)
    end

    def root_module ns
      name = ns.to_s.upcase.to_sym
      @root_module[ns] ||= @root.const_get(name)
    end

    def lookup_const base, name
      path = RUML::Core::Navigation.split_path(name)
      puts([base, path].inspect)
      RUML::Support::Misc.lookup_const(path, base)
    end

    def associate dst, attr, obj, msg=nil
      sel = :"#{attr}_add!"
      dst.send(sel, obj)
    rescue => e
      raise RUML::FactoryError, "associate(#{dst.class}, #{attr.inspect}, #{obj.class}) : #{e} : #{msg} "
    end
  end
end
