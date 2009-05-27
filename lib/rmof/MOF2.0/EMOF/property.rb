module Rmof
  module Mof2_0
    class MultiplicityElement
      mof_property :isReadOnly, Boolean, :default => false
      mof_property :default, String, 0..1
      mof_property :isComposite, Boolean, :default => false
      mof_property :isDerived, Boolean, :default => false
      mof_property :isID, Boolean
      mof_association 1, :opposite, Property, 0..1
    end
  end
end
