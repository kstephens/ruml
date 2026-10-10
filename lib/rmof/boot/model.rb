# Loosely follows subset of MOF/2.5.1.
module RUML::Boot

  class Error < StandardError
    class NotImplementedError < self; end
  end

  # Similar to UML::Property
  class Property
    attr_accessor :name, :value, :elements, :owner
    def initialize(name:, owner:)
      @name = name
      @value = value
      @elements = []
      @owner = owner
    end
  end

  class Base
    attr_accessor :id
    @@id_next = 0

    def initialize(**properities)
      @_properities = {}
      @_operations = {}
      properities.each do | k, v |
        @_properities[k] = v
      end
    end

    def id
      @id ||= (@@id_next += 1)
    end

    def method_missing sel, *args
      raise Error, "{sel} : cannot take block" if block_given?
      case
      when args.empty?
        @_properities[sel]
      when sel.to_s[-1] == "="
        @_properties[sel] = args[0]
      else
        @_operations[sel].call(*args)
      end
    end
  end

  module UML
    class Element < Base
    end
    class NamedElement < Element
    end
    class PackageableElement < Element
    end
    class Namespace < NamedElement
    end
    class Package < Namespace
    end
    class Type < PackageableElement
      # conformsTo(other:) # : Boolean{query}
      def conformsTo(other:)
        raise NotImplementedError, "conformsTo(other:)"
      end
    end
    class Classifier < Type
    end
    class Class < Classifer
    end
    class Property < Base
    end
  end

  module MOF
    module Extension
      class Tag
        attr_accessor :name, :value, :elements, :owner
        def initialize(name:, value:, owner:)
          @name = name
          @value = value
          @elements = []
          @owner = owner
        end
      end
    end

    module Common
      class ReflextiveCollection
        # !RUBY
        include ::Enumerable

        def initialize
          @_objects = []
        end
        # add(object: Object): Boolean
        def add(object:) # : Boolean
          @_objects.push(object)
          true # !!!
        end
        # addAll(elements: ReflectiveSequence): Boolean
        def addAll(elements:)
          result = false
          elements.each do | x |
            # !!! check if object already exists?
            @_objects.push(x)
            result = true # !!!
          end
          result
        end
        # clear()
        def clear()
          @_objects.empty
          nil
        end
        # remove(object: Object): Boolean
        def remove(object:)
          result = @_objects.include?(object)
          @_objects.delete(object)
          result
        end
        # size(): Integer
        def size()
          @_objects.size
        end

        # !RUBY
        def each &block_given
          @_objects.each(&blk)
        end
      end

      class ReflectiveSequence < ReflextiveCollection
        # add(index: Integer, object: Object)
        # add(object: Object)
        def add(index:, object:)
          current = @_objects[index]
          @_objects.insert(index, object)
          current
        end
        # get(index: Integer): Object
        def get(index:)
          @_objects[index]
        end
        # remove(index: Integer): Object
        def remove(index:)
          current = _objects[index]
          @_objects.delete_at(index)
          current
        end
        # set(index: Integer, object: Object): Object
        def set(index:, object:)
          current = @_objects[index]
          @_objects[index] = object
          current
        end
      end
    end

    module Reflection
      class Object < Base
        def get(property:)
          @properities[property]
        end
        def equals(element:) # : Boolean{query}
          element.equals?(self)
        end
        def set(property:, value:) # : Object{query}
          @properities[property] = value
          self
        end
        def isSet(property:) # : Boolean{query}
          @properities.key?(property)
        end
        def unset(property:) #
          @properities.delete(property)
        end
        def invoke(op:, arguments:) # : Object [0..1]
          @operations[op]._invoke(op, arguments)
        end
      end

      class Element < Object
        def initialize(metaclass:)
          @_metaclass = metaclass
        end

        # /metaclass: Class
        def metaclass ; getMetaClass() ; end
        # getMetaClass() : Class
        def getMetaClass()
          @_metaclass
          # raise Unimplemented("getMetaClass")
        end
        # container(): Element
        def container()
          raise NotImplementedError, "container"
        end
      end

      class Factory < Element
        # createFromString(dataType: DataType, string: String): Object
        def createFromString(dataType:, string:)
          raise NotImplementedError("createFromString")
        end
        # convertToString(datatype: DataType, object: Object): String
        def convertToString(datatype:, object:) # : String
          raise NotImplementedError("convertToString")
        end
      end


        def isInstanceOfType(type:, includesSubtypes:) # : Boolean{query}
          raise NotImplementedError("isInstanceOfType")
        end

      class Type
        # isInstance(object: Object) : Boolean{query}
        def isInstance(object:) # : Boolean{query}
          raise NotImplementedError("isInstance")
        end
      end
    end
  end
end
