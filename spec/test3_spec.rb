require 'pp'
$: << File.expand_path(File.dirname(__FILE__) + '/../lib')
$:.uniq!

describe "UML2" do
  it "should handle UnlimtedNatural" do
  require 'ruml/uml2'

  puts RUML::UML2::Core::PrimitiveTypes::UnlimitedNatural::INFINITY.inspect
  puts RUML::UML2::Core::PrimitiveTypes::UnlimitedNatural.coerce(:*)
  end # it
end # describe


