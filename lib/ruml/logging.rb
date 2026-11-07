# frozen_string_literal: true

require 'logger'

module RUML
  module Logging
    attr_accessor :_logger, :_log_verbose
    def _logger ; @_logger ||= ::Logger.new($stderr) ; end
    def _log_prefix ; nil ; end
    def _log msg=nil, &blk
      if @_log_verbose
        _logger.info do
          msg ||= instance_eval(&blk)
          prefix = _log_prefix
          msg = "#{prefix} : #{msg}" if nil != prefix
          msg = "#{self.class} : #{msg}"
          msg
        end
      end
    end
  end
end

