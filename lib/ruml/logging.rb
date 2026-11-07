require 'logger'

module RUML
  module Logging
    attr_accessor :_logger, :_log_verbose
    def _logger ; @_logger ||= ::Logger.new($stderr) ; end
    def _log msg=nil, &blk
      if @_log_verbose
        msg ||= instance_eval(&blk)
        _logger.info("#{self.class} : #{msg}") if msg
      end
    end
  end
end

