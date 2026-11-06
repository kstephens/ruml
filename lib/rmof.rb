# frozen_string_literal: true

module RMOF
  module Boolean; end
  ::FalseClass.extend(Boolean)
  ::TrueClass.extend(Boolean)

  class BaseClass
    def initialize properties
      properties.each do | k, v |
        send(:"#{k}=", v)
      end
    end
  end
end
