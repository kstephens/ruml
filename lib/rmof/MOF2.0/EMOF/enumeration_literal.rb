module Rmof
  module Mof2_0
    class Package < NamedElement
      mof_attribute :uri, String
      mof_association :package, 0..1, :ownedType, Type, 0..N
      mof_association :nestingPackage, 0..1, :nestedPackage, Package, 0..*
    end
  end
end
