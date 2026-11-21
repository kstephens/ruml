# frozen_string_literal: true

require 'ruml/support'

module RUML::Support::Misc
  extend self

  def lookup_const name, root = ::Object
    return nil if name.nil? || name == ""
    name.split("::", -1).reject(&:empty?).inject(root) do | mod, name |
      return nil unless ::Module === mod
      begin
        mod.const_get(name, false)
      rescue NameError
        return nil
      end
    end
  end

  def path_str_parent path # -> String | nil
    return nil if path.nil?
    path = path.to_s
    return nil unless path.include?("::")
    path.sub(/::[^:]*\Z/, '')
  end

  def path_str_base path # -> String | nil
    return nil if path.nil?
    path = path.to_s
    return nil unless path.include?("::")
    path.sub(/\A.*::/, '')
  end

  def or_die(val, msg=nil)
    if val.nil?
      msg ||= yield if block_given?
      msg ||= caller(1)
      raise "#{msg}"
    end
    val
  end
end

