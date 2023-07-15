class Pnmx::Cli::Healthcheck < Pnmx::Cli::Base
  default_command :perform

  desc "perform", "Health check current app version"
  def perform
    on(PNMX.primary_host) do
      begin
        execute *PNMX.healthcheck.run
        Pnmx::Utils::HealthcheckPoller.wait_for_healthy { capture_with_info(*PNMX.healthcheck.status) }
      rescue Pnmx::Utils::HealthcheckPoller::HealthcheckError => e
        error capture_with_info(*PNMX.healthcheck.logs)
        error capture_with_pretty_json(*PNMX.healthcheck.container_health_log)
        raise
      ensure
        execute *PNMX.healthcheck.stop, raise_on_non_zero_exit: false
        execute *PNMX.healthcheck.remove, raise_on_non_zero_exit: false
      end
    end
  end
end
