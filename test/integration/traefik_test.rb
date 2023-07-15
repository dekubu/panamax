require_relative "integration_test"

class TraefikTest < IntegrationTest
  test "boot, stop, start, restart, logs, remove" do
    pnmx :traefik, :boot
    assert_traefik_running

    pnmx :traefik, :stop
    assert_traefik_not_running

    pnmx :traefik, :start
    assert_traefik_running

    pnmx :traefik, :restart
    assert_traefik_running

    logs = pnmx :traefik, :logs, capture: true
    assert_match /Traefik version [\d.]+ built on/, logs

    pnmx :traefik, :remove
    assert_traefik_not_running
  end

  private
    def assert_traefik_running
      assert_match /traefik:v2.9   "\/entrypoint.sh/, traefik_details
    end

    def assert_traefik_not_running
      refute_match /traefik:v2.9   "\/entrypoint.sh/, traefik_details
    end

    def traefik_details
      pnmx :traefik, :details, capture: true
    end
end
