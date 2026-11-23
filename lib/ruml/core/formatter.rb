# frozen_string_literal: true

require 'ruml/core'

module RUML::Core
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
        associations, properties = attributes(obj).partition{|x| x[:isAssociation]}
        return unless emit_basic(obj, properties)
        emit_associations(obj, associations)
        # binding.pry if @depth > 10
      end

      def emit_basic(obj, properties)
        desc = "#{obj.class.name} #{obj.__id__}"
        if @seen[obj.__id__]
          write "^ #{desc} name=#{obj_name(obj).inspect} \n"
          result = false
        else
          @seen[obj.__id__] = obj
          write "#{desc}  { \n"
          attribute_values(obj, properties).each do | name, value |
            @indent += 1
            indent; write "#{name}=#{value.inspect} \n"
            @indent -= 1
          end
          indent; write "}\n"
          result = true
        end
        result
      end

      def emit_associations(obj, associations)
        attribute_values(obj, associations).each do | name, objs |
          objs
          .sort_by do | obj |
            [! @seen[obj.__id__], obj_name(obj)]
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

      def obj_name obj
        obj.name rescue [:UNNAMED]
      end

      def attribute_values obj, attrs
        attrs.map do | prop |
          name = prop[:name]
          sel = :"#{name}_multi!"
          [name, (obj.send(sel) rescue [:UNREACHABLE])]
        end
      end

      def attributes obj
        obj.class.ruml.native_data[:ownedAttribute]
      end

      def indent m=0
        @out.write ". " * (@indent + m)
      end
      def write(s)
        @out.write s
      end
    end
end
