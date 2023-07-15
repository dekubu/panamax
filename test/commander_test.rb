require "test_helper"

class CommanderTest < ActiveSupport::TestCase
  setup do
    configure_with(:deploy_with_roles)
  end

  test "lazy configuration" do
    assert_equal Pnmx::Configuration, @pnmx.config.class
  end

  test "overwriting hosts" do
    assert_equal [ "1.1.1.1", "1.1.1.2", "1.1.1.3", "1.1.1.4" ], @pnmx.hosts

    @pnmx.specific_hosts = [ "1.1.1.1", "1.1.1.2" ]
    assert_equal [ "1.1.1.1", "1.1.1.2" ], @pnmx.hosts
  end

  test "filtering hosts by filtering roles" do
    assert_equal [ "1.1.1.1", "1.1.1.2", "1.1.1.3", "1.1.1.4" ], @pnmx.hosts

    @pnmx.specific_roles = [ "web" ]
    assert_equal [ "1.1.1.1", "1.1.1.2" ], @pnmx.hosts
  end

  test "filtering roles" do
    assert_equal [ "web", "workers" ], @pnmx.roles.map(&:name)

    @pnmx.specific_roles = [ "workers" ]
    assert_equal [ "workers" ], @pnmx.roles.map(&:name)
  end

  test "filtering roles by filtering hosts" do
    assert_equal [ "web", "workers" ], @pnmx.roles.map(&:name)

    @pnmx.specific_hosts = [ "1.1.1.3" ]
    assert_equal [ "workers" ], @pnmx.roles.map(&:name)
  end

  test "overwriting hosts with primary" do
    assert_equal [ "1.1.1.1", "1.1.1.2", "1.1.1.3", "1.1.1.4" ], @pnmx.hosts

    @pnmx.specific_primary!
    assert_equal [ "1.1.1.1" ], @pnmx.hosts
  end

  test "primary_host with specific hosts via role" do
    @pnmx.specific_roles = "workers"
    assert_equal "1.1.1.3", @pnmx.primary_host
  end

  test "roles_on" do
    assert_equal [ "web" ], @pnmx.roles_on("1.1.1.1")
    assert_equal [ "workers" ], @pnmx.roles_on("1.1.1.3")
  end

  test "default group strategy" do
    assert_empty @pnmx.boot_strategy
  end

  test "specific limit group strategy" do
    configure_with(:deploy_with_boot_strategy)

    assert_equal({ in: :groups, limit: 3, wait: 2 }, @pnmx.boot_strategy)
  end

  test "percentage-based group strategy" do
    configure_with(:deploy_with_percentage_boot_strategy)

    assert_equal({ in: :groups, limit: 1, wait: 2 }, @pnmx.boot_strategy)
  end

  private
    def configure_with(variant)
      @pnmx = Pnmx::Commander.new.tap do |pnmx|
        pnmx.configure config_file: Pathname.new(File.expand_path("fixtures/#{variant}.yml", __dir__))
      end
    end
end
