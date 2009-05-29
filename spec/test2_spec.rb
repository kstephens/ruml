require 'pp'
$: << File.expand_path(File.dirname(__FILE__) + '/../lib')
$:.uniq!

describe "Builder" do
  it "should build and compile to Ruby" do
  require 'ruml/builder'

  module MM; end

  b = RUML::Builder.new do
    _package :Pkg1 do

      _package :Types do

        _class :String do
          stereotype :primitive
          method :foo do
            :foo
          end
          method :coerce, :class do | x |
            x
          end
        end

        _class :Integer do
          stereotype :primitive
          method :bar do
            :bar
          end
          method :coerce, :class do | x |
            x
          end
        end
      end

      _package :Pkg2 do
        import :Types

        _class :Cls1 do
          isAbstract true
          property :x, :String, 0..1
          method :to_s do
            "x = #{x.inspect}"
          end
        end

        _class :Cls2, :Cls1 do
          property :y, :Integer, 1..3
          method :to_s do
            super + "; " + (y * ', ')
          end
        end
      end
    end
  end

  # pp b.created.map { | ast | [ :path, ast[:path], :ast, ast ] }

  b.compile(:target => ::MM, :verbose => 9)

  c1 = MM::Pkg1::Pkg2::Cls1
  c1.ancestors.include?(::RUML::Support::Instantiable).should == false

  c2 = MM::Pkg1::Pkg2::Cls2
  c2.ancestors.include?(c1).should == true
  c2.ancestors.include?(::RUML::Support::Instantiable).should == true

  o2 = c2.new(:x => "foobar", :y => [ 1, 2, 3 ])
  
  o2.to_s.should == 'x = "foobar"; 1, 2, 3'

  o3 = lambda { c2.new(:y => [ ])}.should raise_error(ArgumentError)
  o3 = lambda { c2.new(:y => [ 1, 2, 3, 4 ])}.should raise_error(ArgumentError)

  end # it
end # describe



