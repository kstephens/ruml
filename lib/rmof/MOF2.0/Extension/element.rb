module Rmof
  module Mof2_0
    class Element < Object
      mof_property :name, String
      mof_property :value, String
      mof_property :element, String
    end
  end
end
