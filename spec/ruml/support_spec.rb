# frozen_string_literal: true

require 'ruml/support'

describe RUML::Support::Initialize do
  let(:klass) do
    Class.new do
      include RUML::Support::Initialize
      attr_accessor :name
    end
  end

  it 'assigns options through setters' do
    obj = klass.new(name: 'pkg')
    expect(obj.name).to eq('pkg')
  end

  it 'assigns unknown options to instance variables' do
    obj = klass.new(size: 3)
    expect(obj.instance_variable_get(:@size)).to eq(3)
  end

  it 'accepts no options' do
    obj = klass.new
    expect(obj.name).to be_nil
    expect(obj.instance_variable_get(:@opts)).to eq({})
  end

  it 'does not mutate the caller hash' do
    opts = { name: 'pkg' }
    klass.new(opts)
    expect(opts).to eq(name: 'pkg')
  end
end
