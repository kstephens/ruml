module Rmof
  module Mof2_0
    class Class < Type
      mof_property :isAbstract, Boolean, :default => false
      mof_association 1, :ownedAttribute, Property, 0..1, :ordered => true
      mof_association 0..1, :superClass, Class, 0..*
      mof_assocaition :class, 0..1, :ownedOperation, Operation, 0..*, :ordered => true 
    end
  end
end
