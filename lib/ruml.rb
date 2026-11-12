# frozen_string_literal: true

# Ruby UML metamodel implementation
module RUML
  EMPTY_Array = [ ].freeze
  EMPTY_Hash = { }.freeze
  EMPTY_String = ''.freeze
  class Error < StandardError ; end
end

require 'ruml/core/runtime'
require 'ruml/support/extensions'
