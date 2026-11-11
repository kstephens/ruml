# frozen_string_literal: true

require 'rmof'

module RUML
  module XMI
    class Formatter
      def initialize(out: $stdout, max_depth: nil)
        @out = out
        @depth = 0
        @max_depth = max_depth
        @seen = {}
        @indent = 0
      end

      def call(obj)
        emit(obj)
      end

      def emit(obj)
        return unless emit_basic(obj)
        # binding.pry if @depth > 10
        obj._xmi.associations.to_a.sort_by{|(k)| k.to_s}.each do | name, objs |
          objs
          .sort_by do | x |
            [! @seen[obj.__id__], (obj.name rescue "")]
          end
          .each do | obj |
            @depth += 1; @indent += 1
            indent
            write name
            write " "
            if @max_depth && @depth >= @max_depth
              write " (... #{objs.size} items)\n"
            else
              emit(obj)
            end
            @depth -= 1; @indent -= 1
          end
        end
      end

      def emit_basic(obj)
        if RUML::XMI::BaseAttributes === obj
          desc = "#{obj._xmi.kind_name} #{obj._xmi.object_id}"
          id = obj.__id__
        else
          desc = "#{obj.class.name} #{obj.__id__}"
        end
        if @seen[obj.__id__]
          write "^ #{desc} name=#{obj.name.inspect} \n"
          return false
        end
        @seen[obj.__id__] = obj
        write "#{desc}  { \n"
        obj._xmi.properties.each do | name, value |
          @indent += 1
          indent; write "#{name}=#{value.inspect} \n"
          @indent -= 1
        end
        indent; write "}\n"
        true
      end

      def indent m=0
        @out.write ". " * (@indent + m)
      end
      def write(s)
        @out.write s
      end
    end
  end
end
