require_relative "integration_test"

class AccessoryTest < IntegrationTest
  test "boot, stop, start, restart, logs, remove" do
    pnmx :accessory, :boot, :busybox
    assert_accessory_running :busybox

    pnmx :accessory, :stop, :busybox
    assert_accessory_not_running :busybox

    pnmx :accessory, :start, :busybox
    assert_accessory_running :busybox

    pnmx :accessory, :restart, :busybox
    assert_accessory_running :busybox

    logs = pnmx :accessory, :logs, :busybox, capture: true
    assert_match /Starting busybox.../, logs

    pnmx :accessory, :remove, :busybox, "-y"
    assert_accessory_not_running :busybox
  end

  private
    def assert_accessory_running(name)
      assert_match /registry:4443\/busybox:1.36.0   "sh -c 'echo \\"Start/, accessory_details(name)
    end

    def assert_accessory_not_running(name)
      refute_match /registry:4443\/busybox:1.36.0   "sh -c 'echo \\"Start/, accessory_details(name)
    end

    def accessory_details(name)
      pnmx :accessory, :details, name, capture: true
    end
end
