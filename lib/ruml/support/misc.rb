# frozen_string_literal: true

require 'ruml/support'

module RUML::Support::Misc
  extend self
  def or_die(val, msg=nil)
    if val.nil?
      msg ||= yield if block_given?
      msg ||= caller(1)
      raise "#{msg}"
    end
    val
  end
end

