require 'pp'
$: << File.expand_path(File.dirname(__FILE__) + '/lib')

begin
  require 'ruml/builder'

  module MM; end

  b = RUML::Builder.new(:target => MM) do
    _package :Pkg1 do
      _package :Types do
        _class :Type1
        _class :Type2
      end
      _package :Pkg2 do
        import :Types
        _class :Cls1 do
          isAbstract true
          property :x, :Type1, 0..1
        end
        _class :Cls2 do
          specialize :Cls1
          property :y, :Type2, :*
        end
      end
    end
  end

  pp b.created.map { | m | [ m, m.ruml ] }
rescue Exception => err
  $stderr.puts "ERROR: #{err.inspect}\n#{err.backtrace * "\n"}"
  raise err
end


