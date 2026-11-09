# frozen_string_literal: true

require 'ruml/core/primitive_types'

describe RUML::Core::PrimitiveTypes do
  describe "to_native" do
    it "coerces data" do
      pt = RUML::Core::PrimitiveType
      m = RUML::Core::PrimitiveTypes

      values = [nil, true, false, 0, 1, -1, 2.3, "string", "", :symbol, :*, "*"]
      types = [m::Boolean, m::Integer, m::Real, m::String, m::UnlimitedNatural]
      actual = types.flat_map do |type|
        values.map do |value|
          result, error = begin
            [pt.to_native(type, value), nil]
          rescue
            [nil, $!.to_s]
          end
          [type, value, result, error]
        end
      end
      expected = []
      pp(actual)
    end
  end
end
