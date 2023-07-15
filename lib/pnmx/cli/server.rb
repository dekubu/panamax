class Pnmx::Cli::Server < Pnmx::Cli::Base
  desc "bootstrap", "Set up Docker to run PNMX apps"
  def bootstrap
    missing = []

    on(PNMX.hosts | PNMX.accessory_hosts) do |host|
      unless execute(*PNMX.docker.installed?, raise_on_non_zero_exit: false)
        if execute(*PNMX.docker.superuser?, raise_on_non_zero_exit: false)
          info "Missing Docker on #{host}. Installing…"
          execute *PNMX.docker.install
        else
          missing << host
        end
      end
    end

    if missing.any?
      raise "Docker is not installed on #{missing.join(", ")} and can't be automatically installed without having root access and the `curl` command available. Install Docker manually: https://docs.docker.com/engine/install/"
    end
  end
end
