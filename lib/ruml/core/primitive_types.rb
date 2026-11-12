# frozen_string_literal: true

require 'ruml'
require 'ruml/core/runtime'
require 'rational'
require 'complex'

module RUML
  module Core
    module PrimitiveType
      class CoercionError < RUML::Error; end
      UNLIMITED = 12345678901234567890
      def self.included base
        base.extend(ClassMethods)
      end
      module ClassMethods
        def rmof kind, *values
          (@rmof ||= Hash.new { |h, k| h[k] = [] })[kind].concat(values)
        end
      end
      def initialize repr
        @_repr_ = repr
      end
      def self.to_native type, value
        type._coerce_to_native(value)
      rescue
        raise CoercionError, "cannot coerce #{value.inspect} to #{type.inspect}"
      end
    end

    # See: vendor/www.omg.org/spec/UML/20161101/PrimitiveTypes.xmi:
    module PrimitiveTypes
      class Boolean
        include PrimitiveType
        rmof :stereotype, :primitive

        COERCIONS = {
          nil => false,
          0 => false,
          1 => true,
          true => true,
          false => false,
          :true   => true,
          :false  => false,
          'true'  => true,
          'false' => false,
          '1'     => true,
          '0'     => false,
          ""      => false,
        }.freeze

        def self._coerce_to_native x
          case x
          when ::Integer, ::Float, ::Rational, ::Complex then ! x.zero?
          else
            val = COERCIONS[x]
            raise ::ArgumentError, "coerce : #{self} : given #{x.inspect}" if val.nil?
            val
          end
        end
      end

      class Integer
        include PrimitiveType
        rmof :stereotype, :primitive

        def self._coerce_to_native x
          Integer(x)
        end
      end

      class Real
        include PrimitiveType
        rmof :stereotype, :primitive

        def self._coerce_to_native x
          Float(x)
        end
      end

      class String
        include PrimitiveType
        rmof :stereotype, :primitive

        def self._coerce_to_native x
          x.to_s
        end
      end

      class UnlimitedNatural < Integer
        include PrimitiveType
        rmof :stereotype, :primitive

        def self._coerce_to_native x
          case x
          when :*, '*'
            UNLIMITED
          else
            i = x.to_i
            raise ArgumentError, "not >= 0" unless i >= 0
            i
          end
        end

        def self.unlimited
          @unlimited ||= new(UNLIMITED)
        end
      end
    end
  end
end
