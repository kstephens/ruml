# frozen_string_literal: true

require 'stringio'
require 'ruml/support/logging'

describe RUML::Support::Logging::Basic do
  let(:klass) do
    Class.new do
      include RUML::Support::Logging::Basic
    end
  end

  it 'logs messages when log_verbose is enabled' do
    out = StringIO.new
    obj = klass.new
    obj.logger = Logger.new(out)
    obj.log_verbose = true
    obj.log('hello')
    expect(out.string).to include('hello')
  end

  it 'does not log when log_verbose is disabled' do
    out = StringIO.new
    obj = klass.new
    obj.logger = Logger.new(out)
    obj.log('hello')
    expect(out.string).to be_empty
  end
end
