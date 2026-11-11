# frozen_string_literal: true

module RUML

module Runtime
  N = 1000000000000000 unless defined? N
  STAR = (0 .. N) unless defined? STAR

  class Error < StandardError ; end
  class UninstantiatableError < Error ; end

  module Uninstantiatable
    def self.included base
      # super
      base.extend(ModuleMethods)
      base.include(InstanceMethods)
      # !!!
      # base.send(:remove_const, :ModuleMethods)
      # base.send(:remove_const, :InstanceMethods)
    end
    module ModuleMethods
    end
    module InstanceMethods
      def initialize *args
        raise UninstantiatableError, "#{self.class}"
      end
    end
  end

  module Instantiable
    def self.included base
      # super
      base.extend(ModuleMethods)
      base.include(InstanceMethods)
      # !!!
      # base.send(:remove_const, :ModuleMethods)
      # base.send(:remove_const, :InstanceMethods)
    end

    module ModuleMethods
    end

    module InstanceMethods
      def _initialize opts = nil, &blk
        opts ||= EMPTY_Hash
        opts.each do | k, v |
          s = :"#{k}="
          if respond_to? s
            send(s, v)
          else
            instance_variable_set("@#{k}", v)
          end
        end
        if block_given?
          instance_eval(&blk)
        end
        self
      end
      alias :initialize :_initialize
    end
  end
end
end
