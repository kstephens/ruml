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

    def new ns, type, props, id = nil
      if id && (instance = @instance_by_id[id])
        return instance
      end
      # puts("new(#{ns.inspect}, #{type.inspect}) => ...")
      instance = class_module(ns, type).new(props)
      # puts("new(#{ns.inspect}, #{type.inspect}) => #{instance.inspect}")
      # binding.pry
      @instance_by_id[id] = instance if id
      instance
    rescue => e
      reraise e, "new(#{ns.inspect}, #{type.inspect}, #{props.inspect}, #{id.inspect}}"
    end

    def class_module ns, type
      return type if ::Class === type
      @class_module[[ns, type]] ||= _class_module(ns, type)
    end

    def _class_module ns, type
      lookup_const(root_module(ns), type.to_s)
    end

    def root_module ns
      @root_module[ns] ||= @root.const_get(ns.to_s.upcase.to_sym, false)
    end

    def lookup_const base, name
      path = RUML::Core::Navigation.split_path(name.to_s)
      # puts([base, path].inspect)
      RUML::Support::Misc.lookup_const(path, base)
    end

    def associate dst, attr, obj, msg=nil
      sel = :"#{attr}_add!"
      dst.send(sel, obj)
    rescue => e
      reraise e, "associate(#{dst.class}, #{attr.inspect}, #{obj.class}) : #{msg || "..."}"
    end

    def reraise e, msg
      raise RUML::FactoryError, "#{e.inspect} : #{msg}", e.backtrace
    end
  end
end
