# frozen_string_literal: true

require 'rmof'
require 'nokogiri'

module RMOF
  module XMI
    class Formatter
      def initialize out=$stdout
        @out = out
        @depth = 0
        @seen = {}
      end

      def call(obj)
        emit(obj)
      end

      def emit(obj)
        return unless emit_basic(obj)
        # binding.pry if @depth > 10
        obj._xmi.associations.each do | name, objs |
          objs.each do | obj |
            @depth += 1
            indent
            write name
            write " "
            emit(obj)
            @depth -= 1
          end
          binding.pry if name == "defaultValue" && !obj.value.nil?
        end
      end

      def emit_basic(obj)
        # BasicObject does not have a #class method.
        cls = obj._xmi_class
        id = "#{obj.__id__}:#{id.inspect}"
        if @seen[obj.__id__]
          write "#{cls.name} @#{id}\n"
          return false
        end
        @seen[obj.__id__] = obj
        write "#{cls._xmi.type} \##{id} "
        obj._xmi.properties.each do | name, value |
          write "#{name}=#{value.inspect} "
        end
        write "\n"
        true
      end

      def indent
        @out.write "  " * @depth
      end
      def write(s)
        @out.write s
      end
    end
  end
end
