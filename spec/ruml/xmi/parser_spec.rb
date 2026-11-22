# frozen_string_literal: true

require 'tempfile'
require 'ruml/xmi/parser'
require 'ruml/boot/model'
require 'ruml/core/factory'

describe RUML::XMI::Parser do
  subject do
    described_class.new(factory: factory).tap{|o| o.logger.close }
  end
  let(:factory) { RUML::Core::Factory.new(root: factory_root) }
  let(:factory_root) { RUML::Boot::Model }
  let(:url) { "vendor/www.omg.org/spec/UML/20161101/UML.xmi" }

  it 'resolves repeated references to the same object without duplicating associations' do
    root = subject.call(url)
    binding.pry
    model = root.model.first
    klass = model.ownedMember.first
    attributes = klass.ownedAttribute

    expect(attributes.map { |attribute| attribute._.id }).to eq(%w[property other])
  end

  describe "compiled" do
    let(:url) { "vendor/www.omg.org/spec/MOF/20131001/MOF.xmi" }
    it "parses and compiles" do
      root = subject.call(url)
    end
  end
end
