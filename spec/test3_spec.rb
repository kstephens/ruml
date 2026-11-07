# frozen_string_literal: true

require 'ruml/uml2'

describe "UML2" do
  it "should handle UnlimtedNatural" do
    un = RUML::UML2::Core::PrimitiveTypes::UnlimitedNatural
    binding.pry
    ub = un.unbounded

    un.class.inspect.should == 'Class'
    un.coerce(:*).inspect.should == ub.inspect
    un.coerce("*").inspect.should == ub.inspect
  end # it
end # describe
