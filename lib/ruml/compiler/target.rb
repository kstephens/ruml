# frozen_string_literal: true

require 'ruml'
require 'ruml/core/navigation'
require 'ruml/support/initialize'
require 'ruml/support/logging'
require 'ruml/support/context'
require 'stringio'

module RUML
  module Compiler
    # !!! rename to Backend.  Target is confusing.
    # Use an erb template, that has access to Introspection/Navigation.
    class Target
      include Support::Initialize, Support::Logging::Basic

      attr_accessor :frontend, :trace, :depth, :root_node, :root_node_path

      def context
        @context ||= ::RUML::Support.Contexts.new
      end

      def navigator
        @navigator ||= ::RUML::Core::Navigation::Navigator.new
      end

      def fix_name name
        name =name.to_s
        keywords.include?(name) ? "#{name}_" : name
      end

      def keywords
        raise
      end

      # !!! dont need these for ERB.
      # some may become helpers.
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

      def line! *args
        args.each{|x| self << x << " "}
        self << "\n"
        self
      end

      def comment! *args
        msg = "".dup
        args.each{|x| msg << x << " "}
        msg = comment_wrap(msg)
        line! msg
        self
      end

      def comment_wrap msg
        "#{"  " * depth}#{comment_prefix}RUML #{msg}#{comment_suffix}"
      end

      def comment_prefix
        "#"
      end

      def comment_suffix
        ""
      end

      def comment_begin! *args
        line!
        comment! "================================================================================="
        comment! "BEGIN", *args
        self.depth += 1
        line!
      end

      def comment_end! *args
        self.depth -= 1
        line!
        comment! "END  ", *args
        comment! "================================================================================="
        line!
      end

      def depth
        @depth ||= 0
      end

      def indent
        "  " * depth
      end

      def to_s
        out.string
      end

      def find_node_scoped node, path
        return path unless String === path
        navigator.find_node_scoped(node, path)
      end

      def inspect
        "#<#{self.class}:#{self.__id__}>"
      end
    end
  end
end
