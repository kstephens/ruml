# frozen_string_literal: true

require 'ruml/builder'

describe "Builder" do
  it "builds and compiles to Ruby" do

  module MM; end

  b = RUML::Builder.new(target: MM) do | b |
    package :Pkg1 do
      package :Pkg2 do
        import :Types

        class_ :Cls1 do
          property :x, :String, 0..1
          method :to_s do
            "x = #{x.inspect}"
          end
        end

        class_ :Cls2 do
          isAbstract true
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

        class_ :Cls4 do
          generalization :Cls2
          method :to_s do
            inspect
            super + "; " + (y * ', ')
          end
        end

        association \
        :a, :Cls3, 0..1, { }, \
        :b, :Cls1, :*, { }
      end
    end
  end

  # pp b.created.map { | ast | [ :path, ast[:path], :ast, ast ] }

  b._compile(:verbose => 9)

  inst = ::RUML::Support::Instantiable
  uninst = ::RUML::Support::Uninstantiable

  p2 = MM::Pkg1::Pkg2

  c1 = p2::Cls1
  binding.pry
  expect(c1.ancestors).to include(inst)
  expect(c1.ancestors).to include(c1::RUML_InstanceBehavior)

  c2 = p2::Cls2
  expect(c2.ancestors).to include(uninst)
  expect(c2.ancestors).to_not include(c1::RUML_InstanceBehavior)
  expect(c2.ancestors).to include(c2::RUML_InstanceBehavior)

  c3 = p2::Cls3
  expect(c3.ancestors).to include(inst)
  expect(c3.ancestors).to_not include(c1::RUML_InstanceBehavior)
  expect(c3.ancestors).to_not include(c2::RUML_InstanceBehavior)
  expect(c3.ancestors).to include(c3::RUML_InstanceBehavior)

  c4 = p2::Cls4
  expect(c4.ancestors).to include(inst)
  expect(c4.ancestors).to_not include(c1::RUML_InstanceBehavior)
  expect(c4.ancestors).to include(c2::RUML_InstanceBehavior)
  expect(c4.ancestors).to include(c4::RUML_InstanceBehavior)

  o2 = c2.new(:x => "foobar", :y => [ 1, 2, 3 ])

  expect(o2.to_s).to eq('x = "foobar"; 1, 2, 3')

  expect { c2.new(:y => []) }.to raise_error(ArgumentError)
  expect { c2.new(:y => [1, 2, 3, 4]) }.to raise_error(ArgumentError)

  o3 = c3.new(:b => [ o2 ])
  expect(o3.b.size).to eq(1)
  expect(o3.b[0]).to eq(o2)
  expect(o2.a).to eq(o3)

  end # it
end # describe


