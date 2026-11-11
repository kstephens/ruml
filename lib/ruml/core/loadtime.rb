# frozen_string_literal: true

module RUML
  module Core
    class Loadtime
      def initialize mod
        @mod = mod
        @factory = RMOF::XMI::Factory.new
      end

      def meta target, cls, props
        # $stderr.puts "### RUML::Core::Loadtime.meta(#{target.inspect}, #{cls.inspect}, #{props.inspect})"
        obj = @factory.make_instance(:xmi, cls, props)
        yield obj if block_given?
      end
    end
  end
end
