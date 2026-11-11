# frozen_string_literal: true

require 'pry'
require 'pry-byebug'

require 'ruml/xmi/parser'
require 'ruml/xmi/resolver'
require 'ruml/xmi/formatter'
require 'ruml/xmi/compiler'
require 'pathname'

# "vendor/www.omg.org/spec/MOF/20131001/MOF.xmi"
# "vendor/www.omg.org/spec/UML/20161101/UML.xmi"
def parse_xmi input_file
  parser = RUML::XMI::Parser.new
  factory = parser.factory
  root = parser.call(input_file)
  resolver = RUML::XMI::Resolver.new
  # binding.pry
  root = resolver.call(root)
  px(root)
  binding.pry
  root
end
def print_xmi root
  RUML::XMI::Formatter.new.call(root)
end
def px root
  RUML::XMI::Formatter.new(max_depth: 20).call(root)
  nil
end

input_file, output_file = ARGV
output_file ||= "tmp/#{Pathname.new(input_file).basename}.rb"

root = parse_xmi(input_file)
# puts "### ###########################################"
# RUML::XMI::Formatter.new.call(root)
puts "### ###########################################"
$stderr.puts "writing #{output_file}"
File.open(output_file, 'w') do |out|
  RUML::XMI::Compiler.new(out).call(root)
end

begin
  $stderr.puts "loading #{output_file}"
  load(output_file)
rescue => e
  $stderr.puts e.inspect
  e.backtrace.each do | t |
    $stderr.puts t
  end
end

# binding.pry
