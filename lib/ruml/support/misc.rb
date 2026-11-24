# frozen_string_literal: true

require 'ruml/support'
require "zlib"

module RUML::Support::Misc
  extend self

  def underscore(word)
    underscore!(word.to_s.dup)
  end

  def underscore!(word)
    word.gsub!(/([a-z\d]+)([A-Z]+)/, '\1_\2')
    word.gsub!(/([A-Z][A-Z]+)([^A-Z]+)/, '\1_\2')
    word.tr!("-", "_")
    word.downcase!
    word
  end

  def lookup_const path, root = ::Object
    return nil if path.nil? || path == ""
    path_str_split(path).inject(root) do | mod, name |
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
    return nil if path.empty?
    path.sub(/\A.*::/, '')
  end

  def or_die(val, *args)
    if val.nil?
      errors, msgs = args.partition{|x| ::StandardError === x}
      error = errors.first || ::ArgumentError
      msg = msgs.first
      msg = (msg || "").dup
      msg_yield = yield if block_given?
      msg << " : " << msg_yield if msg_yield
      raise ::ArgumentError, "#{msg}"
    end
    val
  end

  def path_str_split name
    return [] if name.nil? || name == ""
    return name if Array === name
    name.to_s.split("::", -1).reject(&:empty?)
  end

  def dynamic_nesting mod
    result = []
    return result unless mod
    path = mod.to_s
    while path
      mod = lookup_const(path)
      result << mod
      path = path_str_parent(path)
    end
    result
  end

  def mkdir_for_file file
    Pathname[file].parent.mkdir_p()
    file
  end

  def with_readonly_file name
    File.chmod(0644, name) rescue Errno::ENOENT
    yield name
    File.chmod(0444, name)
  end
  def write_readonly_file name, content=nil
    File.chmod(0644, name) rescue Errno::ENOENT
    File.open(name, "w+") do | io |
      io.write(content) unless content.nil?
      yield io if block_given?
    end
    File.chmod(0444, name)
  end

  def save_marshal_gz(path, obj, *args)
    Zlib::GzipWriter.open(path, *args) do |gz|
      Marshal.dump(obj, gz)
    end
  end

  def load_marshal_gz(path, *args)
    Zlib::GzipReader.open(path, *args) do |gz|
      Marshal.load(gz)
    end
  end
end

