# frozen_string_literal: true

require 'ruml/support'

module RUML
  module Support
    module BasicObject
      module Repr
        ::RUML::Support.copy_method(self, :__object_id__, ::Object, :object_id)
        ::RUML::Support.copy_method(self, :__class__, ::Kernel, :class)
        ::RUML::Support.copy_method(self, :__caller_locations__, ::Kernel, :caller_locations)
        ::RUML::Support.copy_method(self, :__raise__, ::Kernel, :raise)

        def [] n
          __raise__ "#{n}" unless ::Symbol === n
          _repr[n]
        end
        def []= n, v
          __raise__ "#{n}" unless ::Symbol === n
          _repr[n] = v
        end

        def method_missing name, *args, &blk
          name = name.to_sym
          line = __caller_locations__[0]
          __raise__ "unexpected block" if blk
          # raise "SDKJFSKDJF" if _repr.key?("Cls2")
          case name.to_s
          when /\?\Z/
            $stderr.puts("method_missing #{name.inspect} #{args.inspect}")
            super
          when /\A(.+)=\Z/
            __raise__ "not enough args" if args.empty?
            key = $1.to_sym
            body = ::Kernel.lambda {|val| _repr[key] = val }
          else
            __raise__ "too many args" if args.size > 1
            body = ::Kernel.lambda do | *args |
              if args.size == 1
                _repr[name] = args.first
              else
                _repr[name]
              end
            end
          end
          self.__class__.define_method(name, &body)
          self.__send__(name, *args)
        rescue => e
          exc = ::ArgumentError.new("#{__class__} : #{name} : #{e.inspect}")
          exc.set_backtrace([line.to_s, *e.backtrace])
          __raise__ exc
        end
      end

      class Base < ::BasicObject
        include Repr
        attr_reader :_repr, :_blk, :_line_

        ::RUML::Support.copy_method(self, :hash, ::Object)
        ::RUML::Support.copy_method(self, :eql?, ::Object)

        def initialize h, &blk
          @_repr = h
          @_blk = blk
          @_line_ = (blk&.source_location || "?:?").to_s
        end
        def self.[] *args; new(*args); end
        def nil? ; false ; end
        def to_h ; @_repr ; end
        def inspect detail=false
          return super() if detail
          "<#{__class__}:#{__object_id__} #{_desc_}>"
        end
        def _desc_
          ""
        end
      end
    end
  end
end
