module Rmof
  module Mof2_0
    class Exception
      mof_attribute :objectInError, Element
      mof_attribute :elementInError, Element
      mof_attribute :description, String
    end
  end
end
