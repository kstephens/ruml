# frozen_string_literal: true

require 'ruml/compiler/native'

class RUML::Compiler::Native::TestClass
  attr_accessor :x
  def f(a, b)
    a + b
  end
end

describe RUML::Compiler::Native do
  SUT = RUML::Compiler::Native
  let(:native) { SUT.new }

  describe '.lookup_module' do
    it "looks up a top-level class" do
      result = native.lookup_module('String')
      expect(result).to eq(String)
    end

    it "looks up a nested module" do
      result = native.lookup_module('RUML::Compiler')
      expect(result).to eq(RUML::Compiler)
    end

    it "returns nil for non-existent module" do
      result = native.lookup_module('NonExistent::Module::Path')
      expect(result).to be_nil
    end

    it "returns nil when path component is not a module" do
      result = native.lookup_module('String::NonExistent')
      expect(result).to be_nil
    end
  end

  describe '.build' do
    it "returns nil unchanged" do
      result = native.build(nil)
      expect(result).to be_nil
    end

    it "returns RElement unchanged" do
      element = native.build(String)
      result = native.build(element)
      expect(result.__id__).to eq(element.__id__)
    end

    it "wraps a Class in RClass" do
      result = native.build(String)
      expect(result.__class__).to eq(SUT::RClass)
    end

    it "wraps a Module in RNamespace" do
      result = native.build(RUML::Compiler)
      expect(result.__class__).to eq(SUT::RNamespace)
    end

    it "looks up and wraps a module from string" do
      result = native.build(::RUML::Compiler)
      expect(result.__class__).to eq(SUT::RNamespace)
    end

    it "raises for unsupported types" do
      expect(native.build(42)).to eq(42)
    end
  end

  describe SUT::RNamespace do
    let(:namespace) { native[RUML::Compiler] }

    describe '#name' do
      it "returns the last component of the module name" do
        expect(namespace.name).to eq('Compiler')
      end

      it "caches the name" do
        name1 = namespace.name
        name2 = namespace.name
        expect(name1).to equal(name2)
      end
    end

    describe '#owner' do
      it "returns the parent namespace" do
        owner = namespace.owner
        expect(owner.__class__).to eq(SUT::RNamespace)
        expect(owner.name).to eq('RUML')
      end

      it "caches the owner" do
        owner1 = namespace.owner
        owner2 = namespace.owner
        expect(owner1).to equal(owner2)
      end
    end

    describe '#namespace' do
      it "is an alias for owner" do
        expect(namespace.namespace).to equal(namespace.owner)
      end
    end

    describe '#ownedElement' do
      it "returns module constants that are modules" do
        elements = namespace.ownedElement
        expect(elements).to be_an(Array)
        expect(elements.size >= 2).to eq(true)
        expect(elements.all? { |e| ::SUT::RNamespace === e }).to be true
      end

      it "caches the ownedElement" do
        elements1 = namespace.ownedElement
        elements2 = namespace.ownedElement
        expect(elements1).to equal(elements2)
      end
    end
  end

  let(:rnamespace) { native[RUML::Compiler::Native] }
  let(:rclass) { native[RUML::Compiler::Native::TestClass] }

  describe SUT::RClass do

    describe "#owner" do
      it "finds the correct pareht" do
        expect(rclass.owner.__id__).to eq(rnamespace.__id__)
      end
    end
    describe '#ownedOperation' do
      it "returns an empty array" do
        expect(rclass.ownedOperation.map(&:name)).to eq(["f", "x", "x="])
        expect(rclass.ownedOperation.map(&:owner)).to eq([rclass, rclass, rclass])
      end
    end
  end

  describe SUT::ROperation do
    let(:subject) { rclass.ownedOperation[0] }

    describe '#parameter' do
      it "returns an empty array" do
        expect(subject.name).to eq("f")
        expect(subject.parameter.map(&:name)).to eq([:a, :b])
        expect(subject.parameter.map(&:owner)).to eq([subject, subject])
      end
    end
  end
end
