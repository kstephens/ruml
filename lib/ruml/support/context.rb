# frozen_string_literal: true

module RUML
  module Support
    class Context
      attr_accessor :current

      def initialize name=nil
        @name = nil
        @stack = []
        @current = nil
      end

      def [] i ; @stack[- i] ; end
      def prev ; @stack[-1] ; end
      def depth ; @stack.size ; end
      def with(val)
        @stack.push(@current)
        begin
          yield(@current = val)
        ensure
          @current = @stack.pop
        end
      end
    end
  end

  class Contexts
    def initialize
      @contexts = Hash.new do | h, k |
        h[k] = ::RUML::Support::Context.new(k)
      end
    end
    def [] k ; @contexts[k] ; end
    def method_missing sel, *args, &blk
      case
      when blk && args.size == 1
        @contexts[sel].with(args[0], &blk)
      when args.empty?
        @contexts[sel].current
      else
        super
      end
    end
  end
end
