module Rmof
  module Mof2_0
    class Element < Object
      def initialize opts = { }
        @_slots = { }
      end

      def getMetaClass
        @_metaClass
      end

      def container
        @_container 
      end

      def equals(element)
        return true if self == element
        return false
      end

      def get(property)
        @_slots[property]
      end

      def set(property, value)
        @_slots[property] = value
      end

      def isSet(property)
        @_slots[property] && @_slots[property] != property.default &&
      end

      def unset(property)
        @_slots[property] = nil
      end
    end
  end
end
