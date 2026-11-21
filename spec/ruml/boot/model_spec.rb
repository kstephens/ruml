# frozen_string_literal: true

require 'ruml/boot/model'
require 'ruml/boot/factory'
require 'ruml/core/factory'

describe RUML::Boot::Model do
  let(:model) { RUML::Boot::Model }
  let(:factory) { RUML::Core::Factory.new(model)}
  let(:n1) { factory.new(:UML, :Namespace, name: "N1") }
  let(:c1) { factory.new(:UML, :Class, name: "C1") }

  def build!
    n1.ownedMember_add!(c1)
  end

  it "sets properties" do
    expect(n1.name).to eq("N1")
    expect(c1.name).to eq("C1")
  end

  it "builds and compiles to Ruby" do
    build!
    expect(n1.ownedElement).to include(c1)
    expect(n1.ownedMember).to include(c1)
    expect(c1.namespace).to eq(n1)
    expect(c1.owner).to eq(n1)

    expect(c1.member).to eq(nil) # !!! FIXME
    n1.memberNamespace_add!(c1)
    expect(c1.member).to eq(n1)
  end

  it "generates operations for derived properties" do
    build!
    expect(c1.qualifiedName).to eq("N1::C1")
  end

  let(:e1) { model::UML::VisibilityKind }

  it "defines Enumerations" do
    expect(e1.enumeration_names).to eq(["public", "private", "protected", "package"])
    expect(e1[:public].name).to eq("public")
    expect(e1[:public]).to eq("public")
    expect(e1[:public]).to eq(:public)
    expect(e1[:public].inspect).to eq("#{e1}[:public]")
  end
end
