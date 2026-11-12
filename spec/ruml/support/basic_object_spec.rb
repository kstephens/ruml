# frozen_string_literal: true

require 'ruml/support/basic_object'

describe RUML::Support::BasicObject do
  let(:klass) { Class.new(RUML::Support::BasicObject::Base) }
  let(:repr) { { a: 1 } }
  let(:obj) { klass.new(repr) }

  describe 'Base' do
    it "is a ::BasicObject" do
      expect(klass.ancestors).to include(::BasicObject)
      expect(klass.ancestors.include?(::Kernel)).to eq(false)
    end

    it "exposes the representation hash" do
      expect(obj._repr).to equal(repr)
      expect(obj.to_h).to equal(repr)
    end

    it "records the block and its source location" do
      blk = proc { }
      o = klass.new({}, &blk)
      expect(o._blk).to equal(blk)
      expect(o._line_).to eq(blk.source_location.to_s)
      expect(obj._line_).to eq("?:?")
    end

    it "can be created with .[]" do
      expect(klass[repr].to_h).to equal(repr)
    end

    it "is never nil" do
      expect(obj.nil?).to eq(false)
    end

    it "has an inspect that does not recurse into the representation" do
      expect(obj.inspect).to match(/\A<#{Regexp.escape(klass.to_s)}:\d+ >\z/)
    end
  end

  describe 'Repr' do
    it "reads and writes the representation with Symbol keys" do
      obj[:b] = 2
      expect(obj[:b]).to eq(2)
      expect(repr[:b]).to eq(2)
    end

    it "rejects non-Symbol keys" do
      expect { obj["a"] }.to raise_error(RuntimeError, /a/)
      expect { obj["a"] = 1 }.to raise_error(RuntimeError, /a/)
    end

    it "defines getters and setters on demand through method_missing" do
      expect(obj.a).to eq(1)
      obj.c = 3
      expect(repr[:c]).to eq(3)
      expect(obj.c).to eq(3)
      expect(klass.instance_methods).to include(:c, :c=)
    end

    it "sets a value when a getter is called with one argument" do
      obj.d(4)
      expect(repr[:d]).to eq(4)
    end

    it "returns nil for an unset key" do
      expect(obj.missing).to be_nil
    end

    it "wraps errors in an ArgumentError" do
      expect { obj.e(1, 2) }.to raise_error(ArgumentError, /too many args/)
      expect { obj.e { } }.to raise_error(ArgumentError, /unexpected block/)
    end
  end
end
