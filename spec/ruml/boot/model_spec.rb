# frozen_string_literal: true

require 'ruml/boot/uml3'
require 'ruml/boot/factory'

describe RUML::Boot::Model do
  let(:factory) { RUML::Boot::Factory.new(RUML::Boot::Model)}
  it "builds and compiles to Ruby" do
    ns = factory.new(:UML, :Namespace, name: "ns")
    c1 = factory.new(:UML, :Class, name: "C1")
    # binding.pry
    c1.namespace = ns
  end
end
