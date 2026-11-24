# frozen_string_literal: true

require "zlib"
require "set"
module RUML::Core
module Runtime
  N = 1000000000000000 unless defined? N
  STAR = (0 .. N) unless defined? STAR

  class Error < StandardError ; end
  class UninstantiatableError < Error ; end


  # Metadata hook for Ruby Module
  class Meta
    attr_reader :native, :native_file, :native_line
    attr_accessor :native_data

    def initialize ruby_module
      @native = ruby_module
      @native_data = {}
    end
    def loading(file, line)
      @native_file, @native_line = file, line
      # puts("##RUML loading #{native_file}:#{native_line} : #{@native}")
    end
    def inspect full=false
      return super() if full
      "#<#{self.class} #{@native} #{@native_file}>"
    end
  end

  module BaseClass
    def self.included(target)
      super(target)
      target.extend(RUML_BaseClass_ModuleMethods)
    end

    def __ruml_initialize__ _opts = nil
      self
    end

    module RUML_BaseClass_ModuleMethods
      def ruml
        @__ruml__ ||= Meta.new(self)
      end
    end
  end

  module Uninstantiatable
    include BaseClass
    def self.included target
      super(target)
      target.extend(RUML_Uninstantiatable_ModuleMethods)
      target.include(RUML_Uninstantiatable_InstanceMethods)
    end
    module RUML_Uninstantiatable_ModuleMethods
    end
    module RUML_Uninstantiatable_InstanceMethods
      def initialize *_args
        raise UninstantiatableError, "#{self.class}"
      end
    end
  end

  module Instantiable
    include BaseClass
    def self.included target
      super(target)
      target.extend(RUML_Instantiable_ModuleMethods)
      target.include(RUML_Instantiable_InstanceMethods)
    end

    module RUML_Instantiable_ModuleMethods
    end

    module RUML_Instantiable_InstanceMethods
      def __ruml_initialize__ opts = nil, &blk
        super(opts)
        opts&.each do | k, v |
          s = :"#{k}="
          if respond_to? s
            send(s, v)
          else
            instance_variable_set("@#{k}", v)
          end
        end
        instance_eval(&blk) if blk
        self
      end
      alias :initialize :__ruml_initialize__
    end
  end

    module Import
      def self.importable_names package
        package.constants.reject{|name| name.to_s =~ /\ARUML_/}
      end

      def self.import_package namespace, package
        importable_names(package).each do | name |
          namespace.const_set(name, package.const_get(name))
        end
      end
    end

    module Enumeration
      def self.included(target)
        super(target)
        target.extend(RUML_Enumeration_ClassMethods)
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

      module RUML_Enumeration_ClassMethods
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
