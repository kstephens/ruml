require 'pp'
$: << File.expand_path(File.dirname(__FILE__) + '/../lib')
$:.uniq!

describe "UML2" do
  it "should handle UnlimtedNatural" do
    require 'ruml/uml2'

    un = RUML::UML2::Core::PrimitiveTypes::UnlimitedNatural

    un.class.inspect.should == 'Class'
    un.coerce(:*).inspect.should == '' # FIXME
    un.INFINITY.inspect.should == '' # FIXME
  end # it
end # describe


