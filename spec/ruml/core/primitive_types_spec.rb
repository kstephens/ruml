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
      expected = [[RUML::Core::PrimitiveTypes::Boolean, nil, false, nil],
 [RUML::Core::PrimitiveTypes::Boolean, true, true, nil],
 [RUML::Core::PrimitiveTypes::Boolean, false, false, nil],
 [RUML::Core::PrimitiveTypes::Boolean, 0, false, nil],
 [RUML::Core::PrimitiveTypes::Boolean, 1, true, nil],
 [RUML::Core::PrimitiveTypes::Boolean, -1, true, nil],
 [RUML::Core::PrimitiveTypes::Boolean, 2.3, true, nil],
 [RUML::Core::PrimitiveTypes::Boolean,
  "string",
  nil,
  "cannot coerce \"string\" to RUML::Core::PrimitiveTypes::Boolean"],
 [RUML::Core::PrimitiveTypes::Boolean, "", false, nil],
 [RUML::Core::PrimitiveTypes::Boolean, :symbol, nil, "cannot coerce :symbol to RUML::Core::PrimitiveTypes::Boolean"],
 [RUML::Core::PrimitiveTypes::Boolean, :*, nil, "cannot coerce :* to RUML::Core::PrimitiveTypes::Boolean"],
 [RUML::Core::PrimitiveTypes::Boolean, "*", nil, "cannot coerce \"*\" to RUML::Core::PrimitiveTypes::Boolean"],
 [RUML::Core::PrimitiveTypes::Integer, nil, nil, "cannot coerce nil to RUML::Core::PrimitiveTypes::Integer"],
 [RUML::Core::PrimitiveTypes::Integer, true, nil, "cannot coerce true to RUML::Core::PrimitiveTypes::Integer"],
 [RUML::Core::PrimitiveTypes::Integer, false, nil, "cannot coerce false to RUML::Core::PrimitiveTypes::Integer"],
 [RUML::Core::PrimitiveTypes::Integer, 0, 0, nil],
 [RUML::Core::PrimitiveTypes::Integer, 1, 1, nil],
 [RUML::Core::PrimitiveTypes::Integer, -1, -1, nil],
 [RUML::Core::PrimitiveTypes::Integer, 2.3, 2, nil],
 [RUML::Core::PrimitiveTypes::Integer,
  "string",
  nil,
  "cannot coerce \"string\" to RUML::Core::PrimitiveTypes::Integer"],
 [RUML::Core::PrimitiveTypes::Integer, "", nil, "cannot coerce \"\" to RUML::Core::PrimitiveTypes::Integer"],
 [RUML::Core::PrimitiveTypes::Integer, :symbol, nil, "cannot coerce :symbol to RUML::Core::PrimitiveTypes::Integer"],
 [RUML::Core::PrimitiveTypes::Integer, :*, nil, "cannot coerce :* to RUML::Core::PrimitiveTypes::Integer"],
 [RUML::Core::PrimitiveTypes::Integer, "*", nil, "cannot coerce \"*\" to RUML::Core::PrimitiveTypes::Integer"],
 [RUML::Core::PrimitiveTypes::Real, nil, nil, "cannot coerce nil to RUML::Core::PrimitiveTypes::Real"],
 [RUML::Core::PrimitiveTypes::Real, true, nil, "cannot coerce true to RUML::Core::PrimitiveTypes::Real"],
 [RUML::Core::PrimitiveTypes::Real, false, nil, "cannot coerce false to RUML::Core::PrimitiveTypes::Real"],
 [RUML::Core::PrimitiveTypes::Real, 0, 0.0, nil],
 [RUML::Core::PrimitiveTypes::Real, 1, 1.0, nil],
 [RUML::Core::PrimitiveTypes::Real, -1, -1.0, nil],
 [RUML::Core::PrimitiveTypes::Real, 2.3, 2.3, nil],
 [RUML::Core::PrimitiveTypes::Real, "string", nil, "cannot coerce \"string\" to RUML::Core::PrimitiveTypes::Real"],
 [RUML::Core::PrimitiveTypes::Real, "", nil, "cannot coerce \"\" to RUML::Core::PrimitiveTypes::Real"],
 [RUML::Core::PrimitiveTypes::Real, :symbol, nil, "cannot coerce :symbol to RUML::Core::PrimitiveTypes::Real"],
 [RUML::Core::PrimitiveTypes::Real, :*, nil, "cannot coerce :* to RUML::Core::PrimitiveTypes::Real"],
 [RUML::Core::PrimitiveTypes::Real, "*", nil, "cannot coerce \"*\" to RUML::Core::PrimitiveTypes::Real"],
 [RUML::Core::PrimitiveTypes::String, nil, "", nil],
 [RUML::Core::PrimitiveTypes::String, true, "true", nil],
 [RUML::Core::PrimitiveTypes::String, false, "false", nil],
 [RUML::Core::PrimitiveTypes::String, 0, "0", nil],
 [RUML::Core::PrimitiveTypes::String, 1, "1", nil],
 [RUML::Core::PrimitiveTypes::String, -1, "-1", nil],
 [RUML::Core::PrimitiveTypes::String, 2.3, "2.3", nil],
 [RUML::Core::PrimitiveTypes::String, "string", "string", nil],
 [RUML::Core::PrimitiveTypes::String, "", "", nil],
 [RUML::Core::PrimitiveTypes::String, :symbol, "symbol", nil],
 [RUML::Core::PrimitiveTypes::String, :*, "*", nil],
 [RUML::Core::PrimitiveTypes::String, "*", "*", nil],
 [RUML::Core::PrimitiveTypes::UnlimitedNatural, nil, 0, nil],
 [RUML::Core::PrimitiveTypes::UnlimitedNatural,
  true,
  nil,
  "cannot coerce true to RUML::Core::PrimitiveTypes::UnlimitedNatural"],
 [RUML::Core::PrimitiveTypes::UnlimitedNatural,
  false,
  nil,
  "cannot coerce false to RUML::Core::PrimitiveTypes::UnlimitedNatural"],
 [RUML::Core::PrimitiveTypes::UnlimitedNatural, 0, 0, nil],
 [RUML::Core::PrimitiveTypes::UnlimitedNatural, 1, 1, nil],
 [RUML::Core::PrimitiveTypes::UnlimitedNatural,
  -1,
  nil,
  "cannot coerce -1 to RUML::Core::PrimitiveTypes::UnlimitedNatural"],
 [RUML::Core::PrimitiveTypes::UnlimitedNatural, 2.3, 2, nil],
 [RUML::Core::PrimitiveTypes::UnlimitedNatural, "string", 0, nil],
 [RUML::Core::PrimitiveTypes::UnlimitedNatural, "", 0, nil],
 [RUML::Core::PrimitiveTypes::UnlimitedNatural,
  :symbol,
  nil,
  "cannot coerce :symbol to RUML::Core::PrimitiveTypes::UnlimitedNatural"],
 [RUML::Core::PrimitiveTypes::UnlimitedNatural, :*, 12345678901234567890, nil],
 [RUML::Core::PrimitiveTypes::UnlimitedNatural, "*", 12345678901234567890, nil]]
 expect(actual).to eq(expected)
    end
  end
end
