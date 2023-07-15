class Pnmx::Commands::Auditor < Pnmx::Commands::Base
  attr_reader :details

  def initialize(config, **details)
    super(config)
    @details = details
  end

  # Runs remotely
  def record(line, **details)
    append \
      [ :echo, audit_tags(**details).except(:version, :service_version).to_s, line ],
      audit_log_file
  end

  def reveal
    [ :tail, "-n", 50, audit_log_file ]
  end

  private
    def audit_log_file
      [ "pnmx", config.service, config.destination, "audit.log" ].compact.join("-")
    end

    def audit_tags(**details)
      tags(**self.details, **details)
    end
end
