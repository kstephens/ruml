# frozen_string_literal: true

require 'ruml/core/runtime'
require 'ruml/builder'
require 'rational'
require 'complex'

module RUML
  module Core
    module PrimitiveType
      class CoercionError < RUML::Error; end
      UNLIMITED = 12345678901234567890
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
    RUML::Builder.new(target: self) do
        package :PrimitiveTypes do
          class_ :Boolean do
            include PrimitiveType
            stereotype :primitive

            coercions = {
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
            }

            operation :_coerce_to_native, :class do | x |
              case x
              when ::Integer, ::Float, ::Rational, ::Complex then ! x.zero?
              else
                val = coercions[x]
                raise ::ArgumentError, "coerce : #{self} : given #{x.inspect}" if val.nil?
              end
            end
          end

          class_ :Integer do
            include PrimitiveType
            stereotype :primitive

            operation :_coerce_to_native, :class do | x |
              Integer(x)
            end
          end

          class_ :Real do
            include PrimitiveType
            stereotype :primitive

            operation :_coerce_to_native, :class do | x |
              Float(x)
            end
          end

          class_ :String do
            include PrimitiveType
            stereotype :primitive

            operation :_coerce_to_native, :class do | x |
              x.to_s
            end
          end

          class_ :UnlimitedNatural, :Integer do
            include PrimitiveType
            stereotype :primitive

            operation :_coerce_to_native, :class do | x |
              case x
              when :*, '*'
                UNLIMITED
              else
                i = x.to_i
                raise ArgumentError, "not >= 0" unless i >= 0
                i
              end
            end

            operation :unlimited, :class do
              @unlimited ||= new(UNLIMITED)
            end
          end
        end
      end
    .tap{|b| ::RUML::Compiler::AST::Printer.new().call(b.root)}
    ._compile(language: :ruby)
  end
end
