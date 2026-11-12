# frozen_string_literal: true

require 'ruml/compiler/builder'

module RUML::Spec::MM ; end

describe "Builder" do
  it "builds and compiles to Ruby" do

  m = RUML::Spec::MM

  b = RUML::Compiler::Builder.new(root_namespace: m) do
    package :P1 do
      package :P2 do
        class_ :C1 do
          property :x, String, 0..1
          operation :to_s do
            "#{self.class} : C1.x=#{x.inspect}"
          end
        end

        class_ :C2, :C1 do
          isAbstract true
          property :y, Integer, 1..3
          operation :to_s do
            "#{self.class} : #{super} : C2.y=#{y.inspect}"
          end
        end

        class_ :C3 do
          property :z, Integer, 1..3
          operation :to_s do
            "#{self.class} : C3.z=#{z.inspect}"
          end
        end

        class_ :C4 do
          generalization :C3
          operation :to_s do
            "#{self.class} : #{super()} : C4"
          end
        end

        association \
        :a, :C3, 0..1, { }, \
        :b, :C1, :*, { }
      end
    end
  end

  # pp b.created.map { | ast | [ :path, ast[:path], :ast, ast ] }

  b._compile(verbose: 9, target: :Ruby).eval_code()

  inst = ::RUML::Core::Runtime::Instantiable
  uninst = ::RUML::Core::Runtime::Uninstantiatable

  p2 = m::P1::P2

  c1 = p2::C1
  c2 = p2::C2
  c3 = p2::C3
  c4 = p2::C4

  expect(c1.ancestors).to include(inst)
  expect(c1.ancestors).to include(c1::RUML_InstanceBehavior)

  expect(c2.ancestors).to include(uninst)
  expect(c2.ancestors).to include(c1::RUML_InstanceBehavior)
  expect(c2.ancestors).to include(c2::RUML_InstanceBehavior)

  expect(c3.ancestors).to include(inst)
  expect(c3.ancestors).to_not include(c1::RUML_InstanceBehavior)
  expect(c3.ancestors).to_not include(c2::RUML_InstanceBehavior)
  expect(c3.ancestors).to include(c3::RUML_InstanceBehavior)

  expect(c4.ancestors).to include(inst)
  expect(c4.ancestors).to include(c3::RUML_InstanceBehavior)
  expect(c4.ancestors).to include(c4::RUML_InstanceBehavior)

  o1 = c1.new(:x => "o1", :y => [ 1, 2, 3 ])
  expect(o1).to_not be_nil

  expect { c2.new(:x => "foobar", :y => [ 1, 2, 3 ]) }.to raise_error(RUML::Core::Runtime::UninstantiatableError)

  o3 = c3.new(x: "c3.x", z: [2, 3])
  expect(o3.to_s).to eq("#{m}::P1::P2::C3 : C3.z=[2, 3]")

  o4 = c4.new(z: [2, 3])
  expect(o4.to_s).to eq("#{m}::P1::P2::C4 : #{m}::P1::P2::C4 : C3.z=[2, 3] : C4")

  end
end
