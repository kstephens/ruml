# frozen_string_literal: true

require 'ruml/builder'

describe "Builder" do
  it "should build and compile to Ruby" do

  module MM; end

  b = RUML::Builder.new(target: MM) do
    package :Pkg1 do
      package :Pkg2 do
        import :Types

        class_ :Cls1 do
          isAbstract true
          property :x, :String, 0..1
          method :to_s do
            "x = #{x.inspect}"
          end
        end

        class_ :Cls2 do
          generalization :Cls1
          property :y, :Integer, 1..3
          method :to_s do
            super + "; " + (y * ', ')
          end
        end

        class_ :Cls3 do
          property :z, :Integer, 1..3
          method :to_s do
            super + "; " + (y * ', ')
          end
        end

        association \
        :a, :Cls3, 0..1, { }, \
        :b, :Cls1, :*, { }

      end # package Pkg2

    end # package Pkg1

  end # Builder

  # pp b.created.map { | ast | [ :path, ast[:path], :ast, ast ] }

  b._compile(:verbose => 9)

  c1 = MM::Pkg1::Pkg2::Cls1
  c1.ancestors.include?(::RUML::Support::Instantiable).should == true

  c2 = MM::Pkg1::Pkg2::Cls2
  c2.ancestors.include?(::RUML::Support::Instantiable).should == false
  c2.ancestors.include?(MM::Pkg1::Pkg2::Cls1::RUML_ModuleBehavior).should == true

  c3 = MM::Pkg1::Pkg2::Cls3
  c3.ancestors.include?(MM::Pkg1::Pkg2::Cls1::RUML_ModuleBehavior).should == false
  c3.ancestors.include?(::RUML::Support::Instantiable).should == true

  o2 = c2.new(:x => "foobar", :y => [ 1, 2, 3 ])

  o2.to_s.should == 'x = "foobar"; 1, 2, 3'

  o3 = lambda { c2.new(:y => [ ])}.should raise_error(ArgumentError)
  o3 = lambda { c2.new(:y => [ 1, 2, 3, 4 ])}.should raise_error(ArgumentError)

  o3 = c3.new(:b => [ o2 ])
  o3.b.size.should == 1
  o3.b[0].should == o2
  o2.a.should == o3

  end # it
end # describe



