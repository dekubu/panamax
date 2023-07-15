require_relative "integration_test"

class LockTest < IntegrationTest
  test "acquire, release, status" do
    pnmx :lock, :acquire, "-m 'Integration Tests'"

    status = pnmx :lock, :status, capture: true
    assert_match /Locked by: Deployer at .*\nVersion: #{latest_app_version}\nMessage: Integration Tests/m, status

    error = pnmx :deploy, capture: true, raise_on_error: false
    assert_match /Deploy lock found/m, error

    pnmx :lock, :release

    status = pnmx :lock, :status, capture: true
    assert_match /There is no deploy lock/m, status
  end
end
