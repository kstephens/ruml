# frozen_string_literal: true

require 'ruml/core/notation'

describe RUML::Core::Notation do
  let(:notation) { described_class.new }
  let(:attrs) { %i[visibility isDerived name default isOrdered isUnique isReadOnly lower upper] }
  let(:obj_class) { Struct.new(*attrs) }
  let(:obj) { obj_class.new }

  describe "#property" do
    it "parses a simple property" do
      h = notation.property "+ name : String [0..1]", obj
      expect(h).to include(name: 'name', prop_type: 'String', multiplicity_range: '0..1')
      expect(obj.visibility).to eq :public
      expect(obj.name).to eq :name
      expect(obj.isDerived).to eq false
      expect(obj.isReadOnly).to eq false
      expect(obj.isOrdered).to eq false
      expect(obj.isUnique).to eq true
      expect([obj.lower, obj.upper]).to eq [0, 1]
    end

    it "parses derived properties and modifiers" do
      notation.property "+ /qualifiedName : String [0..1] {readOnly}", obj
      expect(obj.isDerived).to eq true
      expect(obj.name).to eq :qualifiedName
      expect(obj.isReadOnly).to eq true
    end

    it "parses unbounded multiplicity, ordered and nonunique" do
      notation.property "+ body : String [*] {ordered, nonunique}", obj
      expect([obj.lower, obj.upper]).to eq [0, -1]
      expect(obj.isOrdered).to eq true
      expect(obj.isUnique).to eq false
    end

    it "parses defaults" do
      notation.property "+ isSubstitutable : Boolean [0..1] = true", obj
      expect(obj.default).to eq 'true'
    end

    it "parses a default followed directly by modifiers" do
      notation.property "+/lower : Integer [0..1] = 1{readOnly}", obj
      expect(obj.default).to eq '1'
      expect(obj.isReadOnly).to eq true
    end

    it "defaults to public visibility and multiplicity 1" do
      notation.property "isReadOnly : Boolean", obj
      expect(obj.visibility).to eq :public
      expect([obj.lower, obj.upper]).to eq [1, 1]
    end

    it "treats seq as an ordered bag" do
      notation.property "+ items : String [*] {seq}", obj
      expect(obj.isOrdered).to eq true
      expect(obj.isUnique).to eq false
    end

    it "returns nil for unparsable input" do
      expect(notation.property("+ !!!", obj)).to be_nil
    end
  end
end
