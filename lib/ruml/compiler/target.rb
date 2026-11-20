# frozen_string_literal: true

require 'ruml'
require 'ruml/core/navigation'
require 'ruml/support/initialize'
require 'ruml/support/logging'
require 'ruml/support/context'
require 'stringio'

module RUML
  module Compiler
    class Target
      include Support::Initialize, Support::Logging::Basic

      attr_accessor :frontend, :trace

      def context
        @context ||= ::RUML::Support.Contexts.new
      end

      def navigator
        @navigator ||= ::RUML::Core::Navigation::Navigator.new
      end

      def out
        @out ||= StringIO.new
      end

      def << x
        if ::Array === x
          x.each{|x| self << x.to_s << "\n"}
        else
          $stderr << x.to_s if @trace
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
