module Rmof
  module Mof2_0
    class Extent
      def elementsOfType(_type, includeSubtypes) # (Class, Boolean) : Element
      end
      def linksOfType(_type) # (Association) : Link
      end
      def linkedElements(association, endElement, end1ToEnd2Direction) # (: Association, : Element, : Boolean ) : Element
      end
      def linkExist(associaton, firstElement, secondElement)# (: Association,  : Element, : Element) : Boolean
      end
    end
  end
end
