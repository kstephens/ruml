require 'rmof/xmi/parser'
require 'rmof/xmi/resolver'
require 'rmof/xmi/formatter'
require 'rmof/xmi/compiler'
require 'pry'

# "vendor/www.omg.org/spec/MOF/20131001/MOF.xmi"
# "vendor/www.omg.org/spec/UML/20161101/UML.xmi"
def parse_xmi input_file
  xmi = RMOF::XMI::Parser.new.call(input_file)
  root = xmi.root
  root = RMOF::XMI::Resolver.new.call(root)
  root
end
def print_xmi root
  RMOF::XMI::Formatter.new.call(root)
end

input_file, output_file = ARGV
root = parse_xmi(input_file)
# puts "### ###########################################"
# RMOF::XMI::Formatter.new.call(root)
puts "### ###########################################"
File.open(output_file, 'w') do |out|
  RMOF::XMI::Compiler.new(out).call(root)
end

begin
  load(output_file)
rescue
  $stderr.puts $!.inspect
  $!.backtrace.each do | t |
    sstderr.puts t
  end
end

binding.pry
