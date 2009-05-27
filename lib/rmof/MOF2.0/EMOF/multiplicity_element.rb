module Rmof
  module Mof2_0
    class MultiplicityElement
      mof_property :isOrdered, Boolean, :default => false
      mof_property :isUnique, Boolean, :default => true
      mof_property :lower, Integer, :default => 1
      mof_property :upper, UnlimitedNatural, :default => 1
    end
  end
end
