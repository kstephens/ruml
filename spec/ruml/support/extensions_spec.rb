# frozen_string_literal: true

require 'ruml/support/extensions'

describe 'ruml/support/extensions' do
  it 'Hash#project returns values for the given keys in order, nil for missing' do
    expect({ a: 1, b: 2 }.project(:b, :a, :c)).to eq([2, 1, nil])
  end

  it 'Object#meta_def defines a singleton method' do
    obj = Object.new
    obj.meta_def(:hello) { 'hi' }
    expect(obj.hello).to eq('hi')
    expect(Object.new).not_to respond_to(:hello)
  end

  it 'Object#class_def defines an instance method on the class' do
    klass = Class.new
    klass.class_def(:greet) { 'hey' }
    expect(klass.new.greet).to eq('hey')
  end
end
