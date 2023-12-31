require_relative "lib/pnmx/version"

Gem::Specification.new do |spec|
  spec.name        = "pnmx"
  spec.version     = Pnmx::VERSION
  spec.authors     = [ "Delaney Burke" ]
  spec.email       = "delaney@zero2one.ee"
  spec.homepage    = "https://github.com/cococoder/pnmx"
  spec.summary     = "Deploy web apps in containers to lxd containers running Docker with zero downtime"
  spec.license     = "MIT"

  spec.files = Dir["lib/**/*", "MIT-LICENSE", "README.md"]
  spec.executables = %w[ pnmx ]

  spec.add_dependency "activesupport", ">= 7.0"
  spec.add_dependency "lxdkit", "~> 0.0"
  spec.add_dependency "thor", "~> 1.2"
  spec.add_dependency "dotenv", "~> 2.8"
  spec.add_dependency "zeitwerk", "~> 2.5"
  spec.add_dependency "ed25519", "~> 1.2"
  spec.add_dependency "bcrypt_pbkdf", "~> 1.0"

  spec.add_development_dependency "debug"
  spec.add_development_dependency "mocha"
  spec.add_development_dependency "railties"
end
