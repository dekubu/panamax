module Pnmx
end

require "active_support"
require "zeitwerk"

loader = Zeitwerk::Loader.for_gem
loader.ignore("#{__dir__}/pnmx/lxdkit_with_ext.rb")
loader.setup
loader.eager_load # We need all commands loaded.
