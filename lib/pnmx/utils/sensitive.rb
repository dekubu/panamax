require "active_support/core_ext/module/delegation"

class Pnmx::Utils::Sensitive
  # So LXDKit knows to redact these values.
  include LXDKit::Redaction

  attr_reader :unredacted, :redaction
  delegate :to_s, to: :unredacted
  delegate :inspect, to: :redaction

  def initialize(value, redaction: "[REDACTED]")
    @unredacted, @redaction = value, redaction
  end

  # Sensitive values won't leak into YAML output.
  def encode_with(coder)
    coder.represent_scalar nil, redaction
  end
end
