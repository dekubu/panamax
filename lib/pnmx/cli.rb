module Pnmx::Cli
  class LockError < StandardError; end
  class HookError < StandardError; end
end

# LXDKit uses instance eval, so we need a global const for ergonomics
PNMX = Pnmx::Commander.new
