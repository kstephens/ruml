# frozen_string_literal: true

require 'ruml/support/context'

describe RUML::Support::Context do
  subject(:context) { described_class.new(:test) }

  it 'starts with no current value and depth 0' do
    expect(context.current).to be_nil
    expect(context.depth).to eq(0)
  end

  describe '#with' do
    it 'sets current for the duration of the block and restores it afterwards' do
      seen = nil
      context.with(:a) { |v| seen = [v, context.current] }
      expect(seen).to eq([:a, :a])
      expect(context.current).to be_nil
      expect(context.depth).to eq(0)
    end

    it 'tracks nested values through prev and []' do
      context.with(:a) do
        context.with(:b) do
          expect(context.current).to eq(:b)
          expect(context.depth).to eq(2)
          expect(context.prev).to eq(:a)
          expect(context[1]).to eq(:a)
          expect(context[2]).to be_nil
        end
        expect(context.current).to eq(:a)
        expect(context.depth).to eq(1)
      end
    end

    it 'restores state when the block raises' do
      expect { context.with(:a) { raise 'boom' } }.to raise_error('boom')
      expect(context.current).to be_nil
      expect(context.depth).to eq(0)
    end
  end
end
