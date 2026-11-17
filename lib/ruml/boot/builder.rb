# frozen_string_literal: true

require 'ruml'
require 'ruml/core/runtime'
require 'ruml/compiler'
require 'ruml/support/navigable'
require 'ruml/support/basic_object'
require 'ruml/compiler/ast'
require 'ruml/support/logging'
require 'ruml/support/context'
require 'ruml/compiler/frontend'
require 'binding_of_caller'

module RUML::Boot
  class Builder
    def initialize target: nil
      @target = target
      @items = []
    end

    class Enumeration; end
    def enumeration; Enumeration; end

    def _add target, args, blk
      item = [ target, args, blk ]
      # $stderr.puts "#{self.class} _add #{item.inspect}"
      @items << item
      self
    end

    def enum target, args, blk
      name = args[0].to_sym
      target.define_singleton_method(name) { name }
      target.const_set(name, name)
      self
    end

    def property target, args, blk
    end

    def association target, args, blk
    end

    def begin!
      self
    end

    def end!
      @items.each do | item |
        $stderr.puts "#{self.class} end! #{item.inspect}"
      end
      self
    end

    def ximport _kind, target, args, blk
      args.each do | ns |
        ns.constants do | c |
          target.const_set(ns.const_get(c))
        end
      end
    end

    class Item
      attr_accessor :target, :args, :blk
      def initialize target: nil, args: nil, blk: nil
        @target = target
        @args = args
        @blk = blk
      end
    end

    module ModuleMethods
      def ruml *args, &blk
        this = binding.of_caller(1).receiver
        (@@_ruml_ ||= Builder.new)._add(self, args, blk)
      end
      ::Module.include(self)
    end

    module Trace
      TRACEABLES = Module.instance_methods(false).sort - Object.instance_methods - [
        :name, :define_method,
      ]
      TRACEABLES.each do | m |
        define_method(m) do | *args, &blk |
          $stderr.puts "### #{self.name} #{m.inspect} #{args.inspect} #{blk.inspect}"
          super(*args, *blk)
        end
      end
     #  exit!
#       def responds_to?(sel)
#         super(sel)
#       end
#       def method_missing sel, *args, &blk
#         __send__(sel, *args, *blk)
#       end
    end
    # include Trace

  end
end
