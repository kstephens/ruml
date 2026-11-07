# frozen_string_literal: true

require 'rmof/xmi'
require 'rmof/xmi/introspection'

module RUML
  module Traverser
    def initialize_traverse
      @traverse_depth = 0
      @traverse_stack = []
      @traverse_seen = {}
    end

    def traversing ident=nil
      @traverse_ident = ident
      initialize_traverse
      traverse_log ": ..."
      yield
    rescue
      initialize_traverse
      traverse_log ": DONE"
    end

    def traverse obj
      return if @traverse_seen[obj.__id__]
      traverse_log "#{obj}"
      @traverse_seen[obj.__id__] = obj
      traverse_depth_save = @traverse_depth
      @traverse_depth += 1
      begin
        @traverse_stack.push(obj)
        yield obj
      ensure
        @traverse_depth = traverse_depth_save
        @traverse_stack.pop
        traverse_log " : DONE"
      end
    end

    def traverse_log m
      $stderr.puts "### #{self.class.name} : traversing #{@traverse_ident} : #{"  " * @traverse_depth} #{m}"
    end
  end
end
