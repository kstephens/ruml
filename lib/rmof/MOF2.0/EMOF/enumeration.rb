module Rmof
  module Mof2_0
    class Enumeration < DataType
      mof_association :enumeration, 0..1, :ownedLiteral, Enumeration, 0..N, { :ordered => true }
    end
  end
end
