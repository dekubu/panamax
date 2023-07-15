require "test_helper"

class CommandsLockTest < ActiveSupport::TestCase
  setup do
    @config = {
      service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" }, servers: [ "1.1.1.1" ],
      traefik: { "args" => { "accesslog.format" => "json", "metrics.prometheus.buckets" => "0.1,0.3,1.2,5.0" } }
    }
  end

  test "status" do
    assert_equal \
      "stat pnmx_lock > /dev/null && cat pnmx_lock/details | base64 -d",
      new_command.status.join(" ")
  end

  test "acquire" do
    assert_match \
      /mkdir pnmx_lock && echo ".*" > pnmx_lock\/details/m,
      new_command.acquire("Hello", "123").join(" ")
  end

  test "release" do
    assert_match \
      "rm pnmx_lock/details && rm -r pnmx_lock",
      new_command.release.join(" ")
  end

  private
    def new_command
      Pnmx::Commands::Lock.new(Pnmx::Configuration.new(@config, version: "123"))
    end
end
