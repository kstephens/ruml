# frozen_string_literal: true

require 'ruml/core/notation'
require 'ruml/support/basic_object'
require 'ruml/compiler/ast'

describe RUML::Core::Notation do
  let(:subject) { described_class.new(factory) }
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
      obj = subject.property "+ name : String [0..1]"
      # binding.pry
      expect(obj._.properties).to eq(
        {
          :visibility=>:public,
          :name=>"name",
          :type=>"String",
          :default=>nil,
          :isDerived=>false,
          :aggregation => :none,
          :subsets=>[],
          :redefines=>[],
          :isOrdered=>false,
          :isUnique=>true,
          :isReadOnly=>false,
          :isDerivedUnion=>false,
          :isID=>false,
          :lower=>0,
          :upper=>1,
          :opposite => nil,
        })
      expect(obj.visibility).to eq :public
      expect(obj.name).to eq "name"
      expect(obj.type).to eq "String"
      expect(obj.isDerived).to eq false
      expect(obj.isReadOnly).to eq false
      expect(obj.isOrdered).to eq false
      expect(obj.isUnique).to eq true
      expect([obj.lower, obj.upper]).to eq [0, 1]
    end

    it "handles a namespaced type" do
      obj = subject.property("+element : Reflection::Element 0..*")
      expect(obj.type).to eq("Reflection::Element")
    end

    it "parses derived properties and modifiers" do
      obj = subject.property "+ /qualifiedName : String [0..1] {readOnly}"
      expect(obj.isDerived).to eq true
      expect(obj.name).to eq "qualifiedName"
      expect(obj.type).to eq "String"
      expect(obj.isReadOnly).to eq true
    end

    it "parses unbounded multiplicity, ordered and nonunique" do
      obj = subject.property "+ body : String [*] {ordered, nonunique}"
      expect([obj.lower, obj.upper]).to eq [0, -1]
      expect(obj.isOrdered).to eq true
      expect(obj.isUnique).to eq false
    end

    it "parses defaults" do
      obj = subject.property "+ isSubstitutable : Boolean [0..1] = true"
      expect(obj.default).to eq 'true'
    end

    it "parses a default followed directly by modifiers" do
      obj = subject.property "+/lower : Integer [0..1] = 1{readOnly}"
      expect(obj.default).to eq '1'
      expect(obj.isReadOnly).to eq true
    end

    it "defaults to public visibility and multiplicity 1" do
      obj = subject.property "isReadOnly : Boolean"
      expect(obj.visibility).to eq :public
      expect([obj.lower, obj.upper]).to eq [1, 1]
    end

    it "treats seq as an ordered bag" do
      obj = subject.property "+ items : String [*] {seq}"
      expect(obj.isOrdered).to eq true
      expect(obj.isUnique).to eq false
    end
    it "parses opposite" do
      obj = subject.property "+ body : String [*] {ordered, nonunique} (opposite A::b)"
      expect(obj.opposite).to eq("A::b")
    end


    it "returns nil for unparsable input" do
      expect(subject.property("+ !!!")).to be_nil
    end
  end

  describe "#modifiers" do
    let(:modifiers) { subject.modifiers "subsets a, #subsets b, foo, subsets PKG::bar" }
    it "parses uncommented items" do
      expect(modifiers).to eq(["subsets a", "foo", "subsets PKG::bar"])
    end

    describe "#subsets" do
      it "does not strip package names" do
        expect(subject.subsets(modifiers)).to eq(["a", "PKG::bar"])
      end
    end
  end

  describe "#operation" do
    it "parses no parameters and no return type" do
      obj = subject.operation "+ name()"
      props = obj.to_h.dup
      params = props.delete(:parameter)
      expect(props).to eq(
        {
          :isDerived=>false,
          :name=>"name",
          :visibility=>:public,
        }
      )
      expect(params.map(&:to_h)).to eq(
        [
        ]
      )
    end

    it "parses with a return type" do
      $stop_here = true
      obj = subject.operation "+ name() : String [0..1]"
      props = obj.to_h.dup
      params = props.delete(:parameter)
      expect(props).to eq(
        {
          :isDerived=>false,
          :name=>"name",
          :visibility=>:public,
        }
      )
      expect(params.map(&:to_h)).to eq(
        [
          {
            :name=>"return",
            :type=>"String",
            :lower=>0,
            :upper=>1,
            default: nil,
            :direction=>:return,
          },
        ]
      )
    end

    it "parses without a return type" do
      obj = subject.operation "- /name(a : Integer, b : String 2..*)"
      props = obj.to_h.dup
      params = props.delete(:parameter)
      expect(props).to eq(
        {
          :isDerived=>true,
          :name=>"name",
          :visibility=>:private,
        }
      )
      expect(params.map(&:to_h)).to eq(
        [
          {
            :name=>"a",
            :type=>"Integer",
            :lower=>1,
            :upper=>1,
            :direction=>:in,
            default: nil,
          },
          {
            :name=>"b",
            :type=>"String",
            :lower=>2,
            :upper=>-1,
            :direction=>:in,
            default: nil,
          },
        ]
      )
    end
  end
end
