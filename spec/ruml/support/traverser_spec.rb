# frozen_string_literal: true

require 'ruml/support/traverser'

describe RUML::Support::Traverser do
  subject(:traverser) { described_class.new(:test) }

  it 'tracks a stack of pushed items' do
    traverser.push(:a)
    traverser.push(:b)
    expect(traverser.stack).to eq([:a, :b])
    expect(traverser.current).to eq(:b)
  end

  it 'visits each object once' do
    obj = Object.new
    visited = []
    traverser.traverse(obj) { |o| visited << o }
    traverser.traverse(obj) { |o| visited << o }
    expect(visited).to eq([obj])
  end

  it 'pops the traversal stack after yielding' do
    obj = Object.new
    traverser.traverse(obj) { |o| expect(traverser.current).to be(o) }
    expect(traverser.stack).to be_empty
  end
end
