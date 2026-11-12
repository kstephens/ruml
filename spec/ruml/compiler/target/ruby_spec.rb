# frozen_string_literal: true

require 'ruml/compiler/target/ruby'

describe RUML::Compiler::Target::Ruby do
  describe "extract_method_body" do
    it "extracts correctly" do
      input = "t1 do x; end"
      expect(subject.extract_method_body(input)).to eq("x")
      input = "t2 {|| x}; asdfsd"
      expect(subject.extract_method_body(input)).to eq("x")
      input = "t3 {|a| a+5}; asdfsd"
      expect(subject.extract_method_body(input)).to eq("a+5")
      input = "t4 do ||\n x \n end asdfsd"
      expect(subject.extract_method_body(input)).to eq("x")
      input = "t4 do |a|\n a+5 \n end asdfsd"
      expect(subject.extract_method_body(input)).to eq("a+5")
    end
  end
end

