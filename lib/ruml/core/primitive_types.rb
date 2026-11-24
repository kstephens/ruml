# frozen_string_literal: true

require 'ruml'
require 'ruml/core/runtime'
require 'ruml/support/misc'

module RUML::Core
    module PrimitiveType
      RUML_PRIMITIVE = true
      class CoercionError < RUML::Error; end
      UNLIMITED = 12345678901234567890
      def initialize repr
        @_repr_ = repr
      end
    end

    # See: vendor/www.omg.org/spec/UML/20161101/PrimitiveTypes.xmi:
    module PrimitiveTypes
      class Boolean
        include PrimitiveType

        COERCIONS = {
          :true   => true,
          :false  => false,
          'true'  => true,
          'false' => false,
          '1'     => true,
          '0'     => false,
          ""      => false,
        }.freeze

        def self.__ruml_coerce__ x
          case x
          when ::TrueClass, ::FalseClass
            x
          when ::Numeric
            ! x.zero?
          else
            val = COERCIONS[x]
            raise ::CoercionError, "coerce : #{self} : given #{x.inspect}" if val.nil?
            val
          end
        end
      end

      class Integer
        include PrimitiveType

        def self.__ruml_coerce__ x
          Integer(x)
        end
      end

      class Real
        include PrimitiveType

        def self.__ruml_coerce__ x
          Float(x)
        end
      end

      class String
        include PrimitiveType

        def self.__ruml_coerce__ x
          x.to_s
        end
      end

      class UnlimitedNatural < Integer
        include PrimitiveType

        def self.__ruml_coerce__ x
          case x
          when :*, '*'
            UNLIMITED
          else
            i = Integer(x)
            raise CoercionError, "not >= 0" unless i >= 0
            i
          end
        end

        def self.unlimited
          @unlimited ||= new(UNLIMITED)
        end
      end
    end

    module PrimitiveType
      def self.to_native type, value
        type_module(type).__ruml_coerce__(value)
      rescue
        raise ::RUML::Core::PrimitiveType::CoercionError, "cannot coerce #{value.inspect} to #{type.inspect}"
      end

      def self.type_module type
        case type
        when String, Symbol
          PrimitiveTypes.const_get(type.to_sym)
        else
          type
        end
      end

      def self.define_to *types
        types.each do | type |
          mod = type_module(type)
          sel = :"to_#{type}"
          sel_under = RUML::Support::Misc.underscore(sel).to_sym
          blk = Proc.new {|x| to_native(mod, x) }
          define_singleton_method(sel, &blk)
          define_singleton_method(sel_under, &blk)
        end
      end

      define_to :Boolean, :Integer, :Real, :String, :UnlimitedNatural
    end
end
