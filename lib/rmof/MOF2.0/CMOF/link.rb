module Rmof
  module Mof2_0
    class Link < Object
      mof_association :association, Link, 1, :ordered => true
      mof_association :firstElement, Element, 1
      mof_association :secondElement, Element, 1
      def equals(otherLink) # (Link) : Boolean
      end
      def delete # ()
      end
    end
  end
end
