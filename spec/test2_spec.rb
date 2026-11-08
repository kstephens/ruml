# frozen_string_literal: true

require 'ruml/builder'

describe "Builder" do
  it "builds and compiles to Ruby" do

  module MM; end

  b = RUML::Builder.new(target: MM) do | b |
    package :P1 do
      package :P2 do
        import :Types

        class_ :C1 do
          property :x, :String, 0..1
          method :to_s do
            "C1.x=#{x.inspect}"
          end
        end

        class_ :C2, :C1 do
          isAbstract true
          # generalization :C1
          property :y, :Integer, 1..3
          method :to_s do
            super() + "; " + (y * ', ')
          end
        end

        class_ :C3 do
          property :z, :Integer, 1..3
          method :to_s do
            super()) + "; " + (y * ', ')
          end
        end

        class_ :C4 do
          generalization :C3
          method :to_s do
            super() + ": #{z.inspect}"
          end
        end

        association \
        :a, :C3, 0..1, { }, \
        :b, :C1, :*, { }
      end
    end
  end

  # pp b.created.map { | ast | [ :path, ast[:path], :ast, ast ] }

  b._compile(:verbose => 9)

  inst = ::RMOF::Runtime::Instantiable
  uninst = ::RMOF::Runtime::Uninstantiatable

  p2 = MM::P1::P2

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
  expect { c2.new(:x => "foobar", :y => [ 1, 2, 3 ]) }.to raise_error(RMOF::Runtime::UninstantiatableError)

  o3 = c3.new(x: "c3.x", z: "c3.z")
  expect(o3.to_s).to eq('x = "foobar"; 1, 2, 3')

  o4 = c4.new(z: "c4.z")
  expect(o4.to_s).to eq('x = "foobar"; 1, 2, 3')

  end
end

