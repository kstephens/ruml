module Rmof
  module Mof2_0
    class Comment < Element
      mof_attribute :body, String
      mof_association :ownedComment, 0..1, Element, 0..1
      mof_association :_, 0..0, :annotatedElement, NamedElement, 0..*
    end
  end
end
