module Rmof
  module Mof2_0
    # Package Common
    class ReflectiveCollection < Object
      def initialize opts = nil
        @_ = opts.dup || [ ]
      end

      def addObject object # (Object) : Boolean
        if @_.include?(Object)
          false
        else
          @_ << object
          true
        end
      end

      def addAll objects # (ReflectiveSequence) : Boolean
        objects.each do | o |
          addObject(object)
        end
      end

      def clear
        @_.clear
      end

      def remove object # (Object) : Boolean
        @_.delete(object) ? true : false
      end

      def size # () : Integer
        @_.size
      end
    end
  end
end
