require "bundler/setup"
require "active_support/test_case"
require "active_support/testing/autorun"
require "active_support/testing/stream"
require "debug"
require "mocha/minitest" # using #stubs that can alter returns
require "minitest/autorun" # using #stub that take args
require "lxdkit"
require "pnmx"

ActiveSupport::LogSubscriber.logger = ActiveSupport::Logger.new(STDOUT) if ENV["VERBOSE"]

# Applies to remote commands only.
LXDKit.config.backend = LXDKit::Backend::Printer

# Ensure local commands use the printer backend too.
# See https://github.com/capistrano/lxdkit/blob/master/lib/lxdkit/dsl.rb#L9
module LXDKit
  module DSL
    def run_locally(&block)
      LXDKit::Backend::Printer.new(LXDKit::Host.new(:local), &block).run
    end
  end
end

class ActiveSupport::TestCase
  include ActiveSupport::Testing::Stream

  private
    def stdouted
      capture(:stdout) { yield }.strip
    end

    def stderred
      capture(:stderr) { yield }.strip
    end
end
