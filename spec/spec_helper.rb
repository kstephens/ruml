# frozen_string_literal: true

require 'pp'
require 'pry'
require 'pry-byebug'
require 'pry-stack_explorer'
require 'rspec/core/backtrace_formatter'
require 'simplecov'

$: << File.expand_path(File.dirname(__FILE__) + '/../lib')
$:.uniq!

SimpleCov.start do
  # add_filter '/spec/'
  add_filter '/vendor/'
  add_group 'Specs', 'spec'
  cover '{app,lib,spec}/**/*.rb'
end if false

class ::RSpec::Core::BacktraceFormatter
  alias :format_backtrace_super :format_backtrace
  def format_backtrace(backtrace, options = {})
    lines = format_backtrace_super(backtrace, options)
    # Filter, clean, or modify the lines of the backtrace array
    lines.map do |line|
      # Example: Simplify line paths or highlight specific terms
      line.gsub(Dir.pwd + '/', '').sub(/\b:(\d+):in /) { ":#{$1} in " }
    end
  end
end

RSpec.configure do |config|
  # config.expect_with(:rspec) do |expectations|
  #   expectations.syntax = :expect
  # end
end

module RUML
  module Spec
  end
end
