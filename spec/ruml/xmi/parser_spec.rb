# frozen_string_literal: true

require 'tempfile'
require 'ruml/xmi/parser'

describe RUML::XMI::Parser do
  it 'resolves repeated references to the same object without duplicating associations' do
    xml = <<~XML
      <xmi:XMI xmlns:xmi="http://www.omg.org/spec/XMI/20131001">
        <model xmi:type="uml:Model" xmi:id="model">
          <ownedMember xmi:type="uml:Class" xmi:id="class">
            <ownedAttribute xmi:type="uml:Property" xmi:id="property"/>
            <ownedAttribute xmi:idref="property"/>
            <ownedAttribute xmi:type="uml:Property" xmi:id="other"/>
          </ownedMember>
        </model>
      </xmi:XMI>
    XML

    Tempfile.create(['association', '.xmi']) do |file|
      file.write(xml)
      file.flush

      root = described_class.new.call(file.path)
      model = root._xmi.associations[:model].first
      klass = model._xmi.associations[:ownedMember].first
      attributes = klass._xmi.associations[:ownedAttribute]

      expect(attributes.map { |attribute| attribute._xmi.id }).to eq(%w[property other])
    end
  end
end
