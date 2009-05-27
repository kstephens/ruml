module Rmof
  module Mof2_0
    # Package Identifiers
    class ReflectiveCollection < ReflectiveCollection
      def add index, object # (Integer, Object) 
        @_.splice(index, 1, object)
        nil
      end
      def get index # (Integer) : Object
        @_[index]
      end
      def remove index # (Integer) : Boolean
        if @_.size > index
          @_.delete(index)
          true
        else
          false
        end
      end
      def set index, Object # (Integer, Object) : Object
        old = @_[index]
        @_[index] = 
        old
      end
    end
  end
end
