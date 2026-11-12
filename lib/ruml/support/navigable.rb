# frozen_string_literal: true

require 'pp'

module RUML
  module Support
    class Navigable # < BasicObject
      include ::PP::ObjectMixin
      attr_reader :_, :_path
      def self.[] v; _coerce_(v, []); end
      def initialize _, path
        @_ = _
        @_path = path
      end
      def self._coerce_ v, path
        case v
        when EMPTY_ARRAY then v
        when ::Hash, ::Array then self.new(v, path)
        else v
        end
      end
      def [] x; Navigable._coerce_(@_[x], @_path.dup << x); end
      def keys ; @_.keys ; end
      def values ; @_.values ; end
      def empty? ; @_.empty? ; end
      # to_a, to_h
      def == x ; @_ == x; end
      def inspect ; "#<#{self.class} #{_desc_}>" ; end

      %i[method].each{|x| undef_method(x)}

      def _desc_
        path_desc = @_path.map(&:inspect).join('.')
        case @_
        when ::Hash  then "#{path_desc} #{@_.keys.inspect}"
        when ::Array then "#{path_desc} #{(0..@_.size)}"
        else path_desc
        end
      end
      def method_missing sel, *args, &blk
        raise unless args.empty?
        raise if blk
        raise unless ::Symbol === sel
        Navigable._coerce_(self[sel], @_path.dup << sel)
      end
      EMPTY_ARRAY = [].freeze
    end
  end
end
