# frozen_string_literal: true

require 'ruml/xmi/factory'

describe RUML::XMI::Factory do
  describe '#associate' do
    it 'keeps distinct objects and removes repeated references by identity' do
      factory = described_class.new
      parent = factory.make_instance('uml', 'Class')
      first = factory.make_instance('uml', 'Property', { 'name' => 'same' })
      second = factory.make_instance('uml', 'Property', { 'name' => 'same' })

      factory.associate(parent, :ownedAttribute, first)
      factory.associate(parent, :ownedAttribute, second)
      factory.associate(parent, :ownedAttribute, first)

      associations = parent._xmi.associations[:ownedAttribute]
      expect(associations.length).to eq(2)
      expect(associations[0]).to equal(first)
      expect(associations[1]).to equal(second)
    end
  end
end
