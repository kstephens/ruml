module Rmof
  module Mof2_0
    class Operation < MultiplicityElement
      include TypedElement
      mof_association 0..N, :raisedException, Type, 0..*
      mof_assocaition :operation, 1, :ownedParameter, Parameter, 0..*, :ordered => true 
    end
  end
end
