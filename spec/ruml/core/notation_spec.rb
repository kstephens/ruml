# frozen_string_literal: true

require 'ruml/core/notation'
require 'ruml/support/basic_object'
require 'ruml/compiler/ast'

describe RUML::Core::Notation do
  let(:notation) { described_class.new(factory) }
  let(:factory) {
    Class.new do
      define_method(:new) do | _ns, name, parameters |
        obj = RUML::Compiler::AST::Node.new(parameters)
        obj._.metatype = name
        obj
      end
    end.new
  }
  describe "#property" do
    it "parses a simple property" do
      obj = notation.property "+ name : String [0..1]"
      expect(obj._.properties).to eq(
        {
          :visibility=>:public,
         :name=>"name",
         :type=>"String",
         :default=>nil,
         :isDerived=>false,
         :subsets=>[],
         :redefines=>[],
         :isOrdered=>false,
         :isUnique=>true,
         :isReadOnly=>false,
         :isDerivedUnion=>false,
         :isID=>false,
         :lower=>0,
         :upper=>1})
      expect(obj.visibility).to eq :public
      expect(obj.name).to eq "name"
      expect(obj.type).to eq "String"
      expect(obj.isDerived).to eq false
      expect(obj.isReadOnly).to eq false
      expect(obj.isOrdered).to eq false
      expect(obj.isUnique).to eq true
      expect([obj.lower, obj.upper]).to eq [0, 1]
    end

    it "parses derived properties and modifiers" do
      obj = notation.property "+ /qualifiedName : String [0..1] {readOnly}"
      expect(obj.isDerived).to eq true
      expect(obj.name).to eq "qualifiedName"
      expect(obj.type).to eq "String"
      expect(obj.isReadOnly).to eq true
    end

    it "parses unbounded multiplicity, ordered and nonunique" do
      obj = notation.property "+ body : String [*] {ordered, nonunique}"
      expect([obj.lower, obj.upper]).to eq [0, -1]
      expect(obj.isOrdered).to eq true
      expect(obj.isUnique).to eq false
    end

    it "parses defaults" do
      obj = notation.property "+ isSubstitutable : Boolean [0..1] = true"
      expect(obj.default).to eq 'true'
    end

    it "parses a default followed directly by modifiers" do
      obj = notation.property "+/lower : Integer [0..1] = 1{readOnly}"
      expect(obj.default).to eq '1'
      expect(obj.isReadOnly).to eq true
    end

    it "defaults to public visibility and multiplicity 1" do
      obj = notation.property "isReadOnly : Boolean"
      expect(obj.visibility).to eq :public
      expect([obj.lower, obj.upper]).to eq [1, 1]
    end

    it "treats seq as an ordered bag" do
      obj = notation.property "+ items : String [*] {seq}"
      expect(obj.isOrdered).to eq true
      expect(obj.isUnique).to eq false
    end

    it "returns nil for unparsable input" do
      expect(notation.property("+ !!!")).to be_nil
    end
  end

  describe "#operation" do
    it "parses a simple operation" do
      obj = notation.operation "+ name() : String [0..1]"
      props = obj.to_h.dup
      params = props.delete(:parameters)
      expect(props).to eq(
        {:isDerived=>false, :name=>"name", :visibility=>:public}
      )
      expect(params.map(&:to_h)).to eq(
         [
          {:direction=>:return, :lower=>0, :name=>"return", :type=>"String", :upper=>1, :default => nil},
        ]
      )
    end

    it "parses an operation without a return type" do
      obj = notation.operation "- /name(a : Integer)"
      props = obj.to_h.dup
      params = props.delete(:parameters)
      pp(props: props)
      expect(props).to eq(
        {:isDerived=>true, :name=>"name", :visibility=>:private}
      )
      expect(params.map(&:to_h)).to eq(
        [
          {:direction=>:in, :lower=>1, :name=>"a", :type=>"Integer", :upper=>1, default: nil},
        ]
      )
    end
  end
end
