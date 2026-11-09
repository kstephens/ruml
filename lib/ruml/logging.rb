# frozen_string_literal: true

require 'logger'

module RUML
  module Logging
    module Basic
      attr_accessor :logger, :log_verbose, :log_prefix

      def logger
        @logger ||= Logger.new($stderr).tap do | logger |
          logger.formatter = lambda do |severity, datetime, progname, msg|
            # #{datetime.strftime('%Y-%m-%d%H:%M:%S')}
            "  ### #{self.class} #{severity} #{msg}\n"
          end
        end
      end

      def log msg=nil, &blk
        if log_verbose
          logger.info do
            msg ||= instance_eval(&blk)
            prefix = log_prefix
            msg = "#{prefix} : #{msg}" if nil != prefix
            msg = "#{self.class} : #{msg}"
            msg
          end
        end
      end
    end
  end
end

