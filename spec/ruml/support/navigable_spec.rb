# frozen_string_literal: true

require 'ruml/support/navigable'

describe RUML::Support::Navigable do
  let(:data) { { a: { b: 1 }, list: [1, 2] } }

  it 'wraps hashes and arrays and returns scalars unwrapped' do
    nav = described_class[data]
    expect(nav).to be_a(described_class)
    expect(nav[:a]).to be_a(described_class)
    expect(nav[:a][:b]).to eq(1)
  end

  it 'supports method-style access to keys' do
    expect(described_class[data].a.b).to eq(1)
  end

  it 'exposes keys, values, and empty?' do
    nav = described_class[data]
    expect(nav.keys).to eq([:a, :list])
    expect(nav.empty?).to be(false)
    expect(described_class[{}].empty?).to be(true)
  end

  it 'includes the access path in inspect' do
    expect(described_class[data].a.inspect).to include(':a')
  end
end
