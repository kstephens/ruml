# frozen_string_literal: true

module RUML::Core
module Runtime
  N = 1000000000000000 unless defined? N
  STAR = (0 .. N) unless defined? STAR

  class Error < StandardError ; end
  class UninstantiatableError < Error ; end

  module BaseClass
  end

  module Uninstantiatable
    include BaseClass
    def self.included base
      base.extend(ModuleMethods)
      base.include(InstanceMethods)
    end
    module ModuleMethods
    end
    module InstanceMethods
      def initialize *_args
        raise UninstantiatableError, "#{self.class}"
      end
    end
  end

  module Instantiable
    include BaseClass
    def self.included base
      base.extend(ModuleMethods)
      base.include(InstanceMethods)
    end

    module ModuleMethods
    end

    module InstanceMethods
      def __ruml_initialize__ opts = nil, &blk
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
      alias :initialize :__ruml_initialize__
    end
  end
    module Import
      def self.import dst, src
        src.constants do | name |
          dst.const_set(name, src.const_get())
        end
      end
    end

    module Enumeration
      def self.included(target)
        super(target)
        target.extend(ClassMethods)
      end
      attr_reader :name

      alias_method :to_s, :name
      def to_sym ; @to_sym ||= name.to_sym ; end
      def inspect
        @inspect ||= "#{self.class}[#{to_sym.inspect}]".freeze
      end

      def == other
        case other
        when self.class
          equal?(other)
        when ::Symbol
          to_sym == other
        when ::String
          to_s == other
        else
          false
        end
      end

      module ClassMethods
        def __ruml_coerce__ x
          case x
          when self               then x
          when ::Symbol, ::String then enumeration_by_name(x)
          else raise ::ArgumentError, "#{self} : invalid value #{x.inspect}"
          end
        end
        alias_method :[], :__ruml_coerce__
        def enumeration_by_name x
          (@enumeration_by_name ||=
            (
              enumerations.map{|e| [e.name.to_s.freeze, e]} +
              enumerations.map{|e| [e.name.to_sym, e]}
            ).to_h.freeze
          ).fetch(x)
        end
        def enumerations
          @__enumerations__ ||= enumeration_names.map{|name| new(name: name.to_s.freeze)}.freeze
        end
      end
    end
end
end
