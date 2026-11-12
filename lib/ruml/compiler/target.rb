# frozen_string_literal: true

require 'ruml'
require 'ruml/support/initialize'
require 'ruml/support/logging'
require 'stringio'

module RUML
  module Compiler
    class Target
      include Support::Initialize, Support::Logging::Basic

      def out
        @out ||= StringIO.new
      end
      def << x
        if ::Array === x
          x.each{|x| self << x.to_s << "\n"}
        else
          $stderr << x.to_s
          out << x.to_s
        end
        self
      end
      def to_s
        out.string
      end
      def inspect
        "#<#{self.class}:#{self.__id__}>"
      end
    end
  end
end
