require 'pp'
$: << File.expand_path(File.dirname(__FILE__) + '/lib')

begin
  require 'ruml/uml2'

  puts RUML::UML2::Core::PrimitiveTypes::UnlimitedNatural::INFINITY.inspect
  puts RUML::UML2::Core::PrimitiveTypes::UnlimitedNatural.coerce(:*)
rescue Exception => err
  $stderr.puts "ERROR: #{err.inspect}\n#{err.backtrace * "\n"}"
  raise err
end


