require 'pp'
$: << File.expand_path(File.dirname(__FILE__) + '/lib')

begin
  require 'ruml/builder'

  module MM; end

  b = RUML::Builder.new do
    _package :Pkg1 do
      _package :Types do
        _class :Type1 do
          stereotype :primitive
          method :foo do
            :foo
          end
          method :xyz, :class do
            :xyz
          end
        end
        _class :Type2 do
          stereotype :primitive
          method :bar do
            :bar
          end
        end
      end
      _package :Pkg2 do
        import :Types
        _class :Cls1 do
          isAbstract true
          property :x, :Type1, 0..1
        end
        _class :Cls2, :Cls1 do
          property :y, :Type2, :*
        end
      end
    end
  end

  # pp b.created.map { | ast | [ :path, ast[:path], :ast, ast ] }

  b.compile(:target => ::MM, :verbose => 9)

rescue Exception => err
  $stderr.puts "ERROR: #{err.inspect}\n#{err.backtrace * "\n"}"
  raise err
end



