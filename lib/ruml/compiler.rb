
# frozen_string_literal: true

module RUML
  module Compiler
    class CompilerError < StandardError; end
  end
end

require 'ruml/compiler/ast'
require 'ruml/compiler/compiler'
