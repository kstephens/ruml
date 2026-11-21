# frozen_string_literal: true

require 'ruml/boot/model'
require 'ruml/boot/factory'
require 'ruml/core/factory'

describe RUML::Boot::Model do
  let(:model) { RUML::Boot::Model }
  let(:factory) { RUML::Core::Factory.new(model)}
  it "builds and compiles to Ruby" do
    ns = factory.new(:UML, :Namespace, name: "ns")
    c1 = factory.new(:UML, :Class, name: "C1")
    # binding.pry
    c1.namespace = ns
    expect(ns.ownedElement).to include(c1)
    expect(ns.ownedMember).to include(c1)
    # expect(c1.member).to eq(ns) # !!!
    expect(c1.namespace).to eq(ns)
    expect(c1.owner).to eq(ns)
    expect(c1.qualifiedName).to eq("ns::C1")
    expect(model::UML::VisibilityKind.names).to eq(["public", "private", "protected", "package"])
    expect(model::UML::VisibilityKind[:public].name).to eq("public")
    expect(model::UML::VisibilityKind[:public]).to eq("public")
    expect(model::UML::VisibilityKind[:public].inspect).to eq("RUML::Boot::Model::UML::VisibilityKind[:public]")
  end
end
