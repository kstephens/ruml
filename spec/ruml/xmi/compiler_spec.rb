# frozen_string_literal: true

require 'ruml/xmi/compiler'
require 'ruml/xmi/parser'
require 'ruml/xmi/resolver'
require 'ruml/xmi/formatter'
require 'ruml/compiler/frontend'
require 'ruml/compiler/target/ruby'
require 'stringio'

describe RUML::XMI::Compiler do
  describe 'all of it' do
    let(:input_file) { "vendor/www.omg.org/spec/MOF/20131001/MOF.xmi" }
    let(:input_file) { "vendor/www.omg.org/spec/UML/20161101/UML.xmi" }

    it 'parses actual XMI' do
      parser = RUML::XMI::Parser.new
      _factory = parser.factory
      root = parser.call(input_file)
      resolver = RUML::XMI::Resolver.new
      root = resolver.call(root)
      out = StringIO.new
      # binding.pry
      RUML::XMI::Formatter.new(out: out).call(root)
      # puts out.string

      out = StringIO.new
      target = RUML::Compiler::Target::Ruby.new(out: out)
      compiler = RUML::Compiler::Frontend.new(target: target)
      compiler.run(root)
      # puts out.string
    end
  end
end
