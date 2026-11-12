# frozen_string_literal: true

require 'ruml'
require 'ruml/support'
require 'ruml/core/runtime'
require 'ruml/logging'
require 'ruml/compiler/ast'
require 'rmof/code_generator'
require 'method_source'

module RUML
  module Compiler
    class Target
      include Support::Initialize
      def initialize opts
        @opts = (opts || {}).dup
        @out = @opts[:out]
      end
    end
  end
end

