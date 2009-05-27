module Rmof
  module Mof2_0
    class TypedElement < NamedElement
      mof_assocation :type, Type, 0..1
    end
  end
end
