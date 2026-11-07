# frozen_string_literal: true

module Rmof
  module Mof2_0
    class Operation < MultiplicityElement
      include TypedElement
      mof_association 0..N, :raisedException, Type, 0..N
      mof_assocaition :operation, 1, :ownedParameter, Parameter, 0..N, :ordered => true
    end
  end
end
