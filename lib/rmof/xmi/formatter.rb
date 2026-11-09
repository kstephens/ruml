# frozen_string_literal: true

require 'rmof'

module RMOF
  module XMI
    class Formatter
      def initialize(out: $stdout, max_depth: nil)
        @out = out
        @depth = 0
        @max_depth = max_depth
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
            if @max_depth && @depth >= @max_depth
              write " (... #{obj.size} items)\n"
            else
              emit(obj)
            end
            @depth -= 1
          end
        end
      end

      def emit_basic(obj)
        # BasicObject does not have a #class method.
        cls = obj.__class__
        cls_name = cls.name.sub(%r{^#<Module:[^>]+>::}, '')
        id = "#{obj.__id__}:#{id.inspect}"
        if @seen[obj.__id__]
          write "#{cls_name} @#{id}\n"
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
        @out.write ". " * @depth
      end
      def write(s)
        @out.write s
      end
    end
  end
end
