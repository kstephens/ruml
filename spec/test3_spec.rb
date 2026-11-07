# frozen_string_literal: true

require 'ruml/uml2'

describe "UML2" do
  it "handles UnlimitedNatural" do
    un = RUML::UML2::Core::PrimitiveTypes::UnlimitedNatural
    ub = un.unbounded

    expect(un.coerce(:*).inspect).to eq(ub.inspect)
    expect(un.coerce("*").inspect).to eq(ub.inspect)
  end # it
end # describe
