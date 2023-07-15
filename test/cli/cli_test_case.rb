require "test_helper"

class CliTestCase < ActiveSupport::TestCase
  setup do
    ENV["VERSION"]             = "999"
    ENV["RAILS_MASTER_KEY"]    = "123"
    ENV["MYSQL_ROOT_PASSWORD"] = "secret123"
    Object.send(:remove_const, :PNMX)
    Object.const_set(:PNMX, Pnmx::Commander.new)
  end

  teardown do
    ENV.delete("RAILS_MASTER_KEY")
    ENV.delete("MYSQL_ROOT_PASSWORD")
    ENV.delete("VERSION")
  end

  private
    def fail_hook(hook)
      @executions = []
      Pnmx::Commands::Hook.any_instance.stubs(:hook_exists?).returns(true)

      LXDKit::Backend::Abstract.any_instance.stubs(:execute)
        .with { |*args| @executions << args; args != [".pnmx/hooks/#{hook}"] }
      LXDKit::Backend::Abstract.any_instance.stubs(:execute)
        .with { |*args| args.first == ".pnmx/hooks/#{hook}" }
        .raises(LXDKit::Command::Failed.new("failed"))
    end

    def stub_locking
      LXDKit::Backend::Abstract.any_instance.stubs(:execute)
        .with { |arg1, arg2| arg1 == :mkdir && arg2 == :pnmx_lock }
      LXDKit::Backend::Abstract.any_instance.stubs(:execute)
        .with { |arg1, arg2| arg1 == :rm && arg2 == "pnmx_lock/details" }
    end

    def assert_hook_ran(hook, output, version:, service_version:, hosts:, command:, subcommand: nil, runtime: nil)
      performer = `whoami`.strip

      assert_match "Running the #{hook} hook...\n", output

      expected = %r{Running\s/usr/bin/env\s\.pnmx/hooks/#{hook}\sas\s#{performer}@localhost\n\s
        DEBUG\s\[[0-9a-f]*\]\sCommand:\s\(\sexport\s
        PNMX_RECORDED_AT=\"\d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\dZ\"\s
        PNMX_PERFORMER=\"#{performer}\"\s
        PNMX_VERSION=\"#{version}\"\s
        PNMX_SERVICE_VERSION=\"#{service_version}\"\s
        PNMX_HOSTS=\"#{hosts}\"\s
        PNMX_COMMAND=\"#{command}\"\s
        #{"PNMX_SUBCOMMAND=\\\"#{subcommand}\\\"\\s" if subcommand}
        #{"PNMX_RUNTIME=\\\"#{runtime}\\\"\\s" if runtime}
        ;\s/usr/bin/env\s\.pnmx/hooks/#{hook} }x

      assert_match expected, output
    end
end
