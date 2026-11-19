# frozen_string_literal: true

require 'ruml/support'

module RUML::Support
  module Trace
    TRACEABLES = Module.instance_methods(false).sort - Object.instance_methods - [
      :name, :define_method,
    ]
    TRACEABLES.each do | m |
      define_method(m) do | *args, &blk |
        $stderr.puts "### #{self.name} #{m.inspect} #{args.inspect} #{blk.inspect}"
        super(*args, *blk)
      end
    end
  end
end

