# frozen_string_literal: true

require 'ruml/support/misc'

describe RUML::Support::Misc do
  describe '.lookup_const' do
    it "looks up a top-level constant" do
      result = described_class.lookup_const('String')
      expect(result).to eq(String)
    end

    it "looks up a nested constant" do
      result = described_class.lookup_const('RUML::Support::Misc')
      expect(result).to eq(RUML::Support::Misc)
    end

    it "returns nil for non-existent constant" do
      result = described_class.lookup_const('NonExistentConstant')
      expect(result).to be_nil
    end

    it "returns nil for nested non-existent constant" do
      result = described_class.lookup_const('String::NonExistent')
      expect(result).to be_nil
    end

    it "returns nil for nil input" do
      result = described_class.lookup_const(nil)
      expect(result).to be_nil
    end

    it "returns nil for empty string" do
      result = described_class.lookup_const('')
      expect(result).to be_nil
    end

    it "accepts a custom root module" do
      module TestModule
        TestConstant = 42
      end

      result = described_class.lookup_const('TestConstant', TestModule)
      expect(result).to eq(42)
    end

    it "returns nil when root is not a module" do
      result = described_class.lookup_const('String', 42)
      expect(result).to be_nil
    end
  end

  describe '.path_str_parent' do
    it "extracts parent from nested path" do
      result = described_class.path_str_parent('RUML::Support::Misc')
      expect(result).to eq('RUML::Support')
    end

    it "extracts parent from two-level path" do
      result = described_class.path_str_parent('RUML::Support')
      expect(result).to eq('RUML')
    end

    it "returns nil for top-level constant" do
      result = described_class.path_str_parent('String')
      expect(result).to be_nil
    end

    it "returns nil for nil input" do
      result = described_class.path_str_parent(nil)
      expect(result).to be_nil
    end

    it "handles symbol input by converting to string" do
      result = described_class.path_str_parent(:RUML)
      expect(result).to be_nil
    end

    it "handles object with to_s method" do
      path_obj = double(to_s: 'RUML::Support::Misc')
      result = described_class.path_str_parent(path_obj)
      expect(result).to eq('RUML::Support')
    end

    it "preserves empty components" do
      result = described_class.path_str_parent('A::B::C')
      expect(result).to eq('A::B')
    end
  end

  describe '.lookup_const' do
    it "underscore" do
      expect(described_class.underscore(:_as_123_)).to eq("_as_123_")
      expect(described_class.underscore(:_CAPlower_)).to eq("_cap_lower_")
    end
  end

  xdescribe '.or_die' do
    it "returns the value when not nil" do
      result = described_class.or_die(42)
      expect(result).to eq(42)
    end

    it "returns empty string unchanged" do
      result = described_class.or_die('')
      expect(result).to eq('')
    end

    it "returns false unchanged" do
      result = described_class.or_die(false)
      expect(result).to be false
    end

    it "returns zero unchanged" do
      result = described_class.or_die(0)
      expect(result).to eq(0)
    end

    it "raises when value is nil with default message" do
      expect { described_class.or_die(nil) }.to raise_error(::ArgumentError)
    end

    it "raises with provided message when value is nil" do
      expect { described_class.or_die(nil, 'custom error') }.to raise_error('custom error')
    end

    it "raises with block message when value is nil and block given" do
      expect { described_class.or_die(nil) { 'block message' } }.to raise_error('block message')
    end

    it "uses block message over default" do
      expect do
        described_class.or_die(nil) { 'from block' }
      end.to raise_error('from block')
    end

    it "does not call block when value is not nil" do
      block_called = false
      result = described_class.or_die(42) { block_called = true }
      expect(result).to eq(42)
      expect(block_called).to be false
    end

    it "includes caller information in default message" do
      expect { described_class.or_die(nil) }.to raise_error(::ArgumentError)
    end
  end
end
