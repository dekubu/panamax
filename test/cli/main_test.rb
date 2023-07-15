require_relative "cli_test_case"

class CliMainTest < CliTestCase
  test "setup" do
    Pnmx::Cli::Main.any_instance.expects(:invoke).with("pnmx:cli:server:bootstrap")
    Pnmx::Cli::Main.any_instance.expects(:invoke).with("pnmx:cli:accessory:boot", [ "all" ])
    Pnmx::Cli::Main.any_instance.expects(:deploy)

    run_command("setup")
  end

  test "deploy" do
    invoke_options = { "config_file" => "test/fixtures/deploy_simple.yml", "version" => "999", "skip_hooks" => false }

    Pnmx::Cli::Main.any_instance.expects(:invoke).with("pnmx:cli:registry:login", [], invoke_options)
    Pnmx::Cli::Main.any_instance.expects(:invoke).with("pnmx:cli:build:deliver", [], invoke_options)
    Pnmx::Cli::Main.any_instance.expects(:invoke).with("pnmx:cli:traefik:boot", [], invoke_options)
    Pnmx::Cli::Main.any_instance.expects(:invoke).with("pnmx:cli:healthcheck:perform", [], invoke_options)
    Pnmx::Cli::Main.any_instance.expects(:invoke).with("pnmx:cli:app:stale_containers", [], invoke_options)
    Pnmx::Cli::Main.any_instance.expects(:invoke).with("pnmx:cli:app:boot", [], invoke_options)
    Pnmx::Cli::Main.any_instance.expects(:invoke).with("pnmx:cli:prune:all", [], invoke_options)

    Pnmx::Commands::Hook.any_instance.stubs(:hook_exists?).returns(true)
    hook_variables = { version: 999, service_version: "app@999", hosts: "1.1.1.1,1.1.1.2", command: "deploy" }

    run_command("deploy").tap do |output|
      assert_hook_ran "pre-connect", output, **hook_variables
      assert_match /Log into image registry/, output
      assert_match /Build and push app image/, output
      assert_hook_ran "pre-deploy", output, **hook_variables
      assert_match /Ensure Traefik is running/, output
      assert_match /Ensure app can pass healthcheck/, output
      assert_match /Detect stale containers/, output
      assert_match /Prune old containers and images/, output
      assert_hook_ran "post-deploy", output, **hook_variables, runtime: 0
    end
  end

  test "deploy with skip_push" do
    invoke_options = { "config_file" => "test/fixtures/deploy_simple.yml", "version" => "999", "skip_hooks" => false }

    Pnmx::Cli::Main.any_instance.expects(:invoke).with("pnmx:cli:registry:login", [], invoke_options)
    Pnmx::Cli::Main.any_instance.expects(:invoke).with("pnmx:cli:build:pull", [], invoke_options)
    Pnmx::Cli::Main.any_instance.expects(:invoke).with("pnmx:cli:traefik:boot", [], invoke_options)
    Pnmx::Cli::Main.any_instance.expects(:invoke).with("pnmx:cli:healthcheck:perform", [], invoke_options)
    Pnmx::Cli::Main.any_instance.expects(:invoke).with("pnmx:cli:app:stale_containers", [], invoke_options)
    Pnmx::Cli::Main.any_instance.expects(:invoke).with("pnmx:cli:app:boot", [], invoke_options)
    Pnmx::Cli::Main.any_instance.expects(:invoke).with("pnmx:cli:prune:all", [], invoke_options)

    run_command("deploy", "--skip_push").tap do |output|
      assert_match /Acquiring the deploy lock/, output
      assert_match /Log into image registry/, output
      assert_match /Pull app image/, output
      assert_match /Ensure Traefik is running/, output
      assert_match /Ensure app can pass healthcheck/, output
      assert_match /Detect stale containers/, output
      assert_match /Prune old containers and images/, output
      assert_match /Releasing the deploy lock/, output
    end
  end

  test "deploy when locked" do
    Thread.report_on_exception = false

    LXDKit::Backend::Abstract.any_instance.stubs(:execute)
      .with { |*arg| arg[0..1] == [:mkdir, :pnmx_lock] }
      .raises(RuntimeError, "mkdir: cannot create directory ‘pnmx_lock’: File exists")

    LXDKit::Backend::Abstract.any_instance.expects(:capture_with_debug)
      .with(:stat, :pnmx_lock, ">", "/dev/null", "&&", :cat, "pnmx_lock/details", "|", :base64, "-d")

    assert_raises(Pnmx::Cli::LockError) do
      run_command("deploy")
    end
  end

  test "deploy error when locking" do
    Thread.report_on_exception = false

    LXDKit::Backend::Abstract.any_instance.stubs(:execute)
      .with { |*arg| arg[0..1] == [:mkdir, :pnmx_lock] }
      .raises(SocketError, "getaddrinfo: nodename nor servname provided, or not known")

    assert_raises(LXDKit::Runner::ExecuteError) do
      run_command("deploy")
    end
  end

  test "deploy errors during outside section leave remove lock" do
    invoke_options = { "config_file" => "test/fixtures/deploy_simple.yml", "version" => "999", "skip_hooks" => false }

    Pnmx::Cli::Main.any_instance.expects(:invoke)
      .with("pnmx:cli:registry:login", [], invoke_options)
      .raises(RuntimeError)

    assert !PNMX.holding_lock?
    assert_raises(RuntimeError) do
      stderred { run_command("deploy") }
    end
    assert !PNMX.holding_lock?
  end

  test "deploy with skipped hooks" do
    invoke_options = { "config_file" => "test/fixtures/deploy_simple.yml", "version" => "999", "skip_hooks" => true }

    Pnmx::Cli::Main.any_instance.expects(:invoke).with("pnmx:cli:registry:login", [], invoke_options)
    Pnmx::Cli::Main.any_instance.expects(:invoke).with("pnmx:cli:build:deliver", [], invoke_options)
    Pnmx::Cli::Main.any_instance.expects(:invoke).with("pnmx:cli:traefik:boot", [], invoke_options)
    Pnmx::Cli::Main.any_instance.expects(:invoke).with("pnmx:cli:healthcheck:perform", [], invoke_options)
    Pnmx::Cli::Main.any_instance.expects(:invoke).with("pnmx:cli:app:stale_containers", [], invoke_options)
    Pnmx::Cli::Main.any_instance.expects(:invoke).with("pnmx:cli:app:boot", [], invoke_options)
    Pnmx::Cli::Main.any_instance.expects(:invoke).with("pnmx:cli:prune:all", [], invoke_options)

    run_command("deploy", "--skip_hooks") do
      refute_match /Running the post-deploy hook.../, output
    end
  end

  test "deploy with missing secrets" do
    assert_raises(KeyError) do
      run_command("deploy", config_file: "deploy_with_secrets")
    end
  end

  test "redeploy" do
    invoke_options = { "config_file" => "test/fixtures/deploy_simple.yml", "version" => "999", "skip_hooks" => false }

    Pnmx::Cli::Main.any_instance.expects(:invoke).with("pnmx:cli:build:deliver", [], invoke_options)
    Pnmx::Cli::Main.any_instance.expects(:invoke).with("pnmx:cli:healthcheck:perform", [], invoke_options)
    Pnmx::Cli::Main.any_instance.expects(:invoke).with("pnmx:cli:app:stale_containers", [], invoke_options)
    Pnmx::Cli::Main.any_instance.expects(:invoke).with("pnmx:cli:app:boot", [], invoke_options)

    Pnmx::Commands::Hook.any_instance.stubs(:hook_exists?).returns(true)

    hook_variables = { version: 999, service_version: "app@999", hosts: "1.1.1.1,1.1.1.2", command: "redeploy" }

    run_command("redeploy").tap do |output|
      assert_hook_ran "pre-connect", output, **hook_variables
      assert_match /Build and push app image/, output
      assert_hook_ran "pre-deploy", output, **hook_variables
      assert_match /Running the pre-deploy hook.../, output
      assert_match /Ensure app can pass healthcheck/, output
      assert_hook_ran "post-deploy", output, **hook_variables, runtime: "0"
    end
  end

  test "redeploy with skip_push" do
    invoke_options = { "config_file" => "test/fixtures/deploy_simple.yml", "version" => "999", "skip_hooks" => false }

    Pnmx::Cli::Main.any_instance.expects(:invoke).with("pnmx:cli:build:pull", [], invoke_options)
    Pnmx::Cli::Main.any_instance.expects(:invoke).with("pnmx:cli:healthcheck:perform", [], invoke_options)
    Pnmx::Cli::Main.any_instance.expects(:invoke).with("pnmx:cli:app:stale_containers", [], invoke_options)
    Pnmx::Cli::Main.any_instance.expects(:invoke).with("pnmx:cli:app:boot", [], invoke_options)

    run_command("redeploy", "--skip_push").tap do |output|
      assert_match /Pull app image/, output
      assert_match /Ensure app can pass healthcheck/, output
    end
  end

  test "rollback bad version" do
    Thread.report_on_exception = false

    run_command("details") # Preheat PNMX const

    run_command("rollback", "nonsense").tap do |output|
      assert_match /docker container ls --all --filter name=\^app-web-nonsense\$ --quiet/, output
      assert_match /The app version 'nonsense' is not available as a container/, output
    end
  end

  test "rollback good version" do
    [ "web", "workers" ].each do |role|
      LXDKit::Backend::Abstract.any_instance.expects(:capture_with_info)
        .with(:docker, :container, :ls, "--filter", "name=^app-#{role}-123$", "--quiet", raise_on_non_zero_exit: false)
        .returns("").at_least_once
      LXDKit::Backend::Abstract.any_instance.expects(:capture_with_info)
        .with(:docker, :container, :ls, "--all", "--filter", "name=^app-#{role}-123$", "--quiet")
        .returns("version-to-rollback\n").at_least_once
      LXDKit::Backend::Abstract.any_instance.expects(:capture_with_info)
        .with(:docker, :ps, "--filter", "label=service=app", "--filter", "label=role=#{role}", "--filter", "status=running", "--filter", "status=restarting", "--latest", "--format", "\"{{.Names}}\"", "|", "grep -oE \"\\-[^-]+$\"", "|", "cut -c 2-", raise_on_non_zero_exit: false)
        .returns("version-to-rollback\n").at_least_once
      LXDKit::Backend::Abstract.any_instance.expects(:capture_with_info)
        .with(:docker, :container, :ls, "--all", "--filter", "name=^app-#{role}-123$", "--quiet", "|", :xargs, :docker, :inspect, "--format", "'{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}'")
        .returns("running").at_least_once # health check
    end

    Pnmx::Commands::Hook.any_instance.stubs(:hook_exists?).returns(true)
    hook_variables = { version: 123, service_version: "app@123", hosts: "1.1.1.1,1.1.1.2,1.1.1.3,1.1.1.4", command: "rollback" }

    run_command("rollback", "123", config_file: "deploy_with_accessories").tap do |output|
      assert_match "Start container with version 123", output
      assert_hook_ran "pre-deploy", output, **hook_variables
      assert_match "docker tag dhh/app:123 dhh/app:latest", output
      assert_match "docker start app-web-123", output
      assert_match "docker container ls --all --filter name=^app-web-version-to-rollback$ --quiet | xargs docker stop", output, "Should stop the container that was previously running"
      assert_hook_ran "post-deploy", output, **hook_variables, runtime: "0"
    end
  end

  test "rollback without old version" do
    Pnmx::Cli::Main.any_instance.stubs(:container_available?).returns(true)

    Pnmx::Utils::HealthcheckPoller.stubs(:sleep)

    LXDKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :container, :ls, "--filter", "name=^app-web-123$", "--quiet", raise_on_non_zero_exit: false)
      .returns("").at_least_once
    LXDKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :ps, "--filter", "label=service=app", "--filter", "label=role=web", "--filter", "status=running", "--filter", "status=restarting", "--latest", "--format", "\"{{.Names}}\"", "|", "grep -oE \"\\-[^-]+$\"", "|", "cut -c 2-", raise_on_non_zero_exit: false)
      .returns("").at_least_once
    LXDKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "name=^app-web-123$", "--quiet", "|", :xargs, :docker, :inspect, "--format", "'{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}'")
      .returns("running").at_least_once # health check

    run_command("rollback", "123").tap do |output|
      assert_match "Start container with version 123", output
      assert_match "docker start app-web-123 || docker run --detach --restart unless-stopped --name app-web-123", output
      assert_no_match "docker stop", output
    end
  end

  test "details" do
    Pnmx::Cli::Main.any_instance.expects(:invoke).with("pnmx:cli:traefik:details")
    Pnmx::Cli::Main.any_instance.expects(:invoke).with("pnmx:cli:app:details")
    Pnmx::Cli::Main.any_instance.expects(:invoke).with("pnmx:cli:accessory:details", [ "all" ])

    run_command("details")
  end

  test "audit" do
    run_command("audit").tap do |output|
      assert_match /tail -n 50 pnmx-app-audit.log on 1.1.1.1/, output
      assert_match /App Host: 1.1.1.1/, output
    end
  end

  test "config" do
    run_command("config", config_file: "deploy_simple").tap do |output|
      config = YAML.load(output)

      assert_equal ["web"], config[:roles]
      assert_equal ["1.1.1.1", "1.1.1.2"], config[:hosts]
      assert_equal "999", config[:version]
      assert_equal "dhh/app", config[:repository]
      assert_equal "dhh/app:999", config[:absolute_image]
      assert_equal "app-999", config[:service_with_version]
    end
  end

  test "config with roles" do
    run_command("config", config_file: "deploy_with_roles").tap do |output|
      config = YAML.load(output)

      assert_equal ["web", "workers"], config[:roles]
      assert_equal ["1.1.1.1", "1.1.1.2", "1.1.1.3", "1.1.1.4"], config[:hosts]
      assert_equal "999", config[:version]
      assert_equal "registry.digitalocean.com/dhh/app", config[:repository]
      assert_equal "registry.digitalocean.com/dhh/app:999", config[:absolute_image]
      assert_equal "app-999", config[:service_with_version]
    end
  end

  test "config with destination" do
    run_command("config", "-d", "world", config_file: "deploy_for_dest").tap do |output|
      config = YAML.load(output)

      assert_equal ["web"], config[:roles]
      assert_equal ["1.1.1.1", "1.1.1.2"], config[:hosts]
      assert_equal "999", config[:version]
      assert_equal "registry.digitalocean.com/dhh/app", config[:repository]
      assert_equal "registry.digitalocean.com/dhh/app:999", config[:absolute_image]
      assert_equal "app-999", config[:service_with_version]
    end
  end

  test "init" do
    Pathname.any_instance.expects(:exist?).returns(false).times(3)
    Pathname.any_instance.stubs(:mkpath)
    FileUtils.stubs(:mkdir_p)
    FileUtils.stubs(:cp_r)
    FileUtils.stubs(:cp)

    run_command("init").tap do |output|
      assert_match /Created configuration file in config\/deploy.yml/, output
      assert_match /Created \.env file/, output
    end
  end

  test "init with existing config" do
    Pathname.any_instance.expects(:exist?).returns(true).times(3)

    run_command("init").tap do |output|
      assert_match /Config file already exists in config\/deploy.yml \(remove first to create a new one\)/, output
    end
  end

  test "init with bundle option" do
    Pathname.any_instance.expects(:exist?).returns(false).times(4)
    Pathname.any_instance.stubs(:mkpath)
    FileUtils.stubs(:mkdir_p)
    FileUtils.stubs(:cp_r)
    FileUtils.stubs(:cp)

    run_command("init", "--bundle").tap do |output|
      assert_match /Created configuration file in config\/deploy.yml/, output
      assert_match /Created \.env file/, output
      assert_match /Adding PNMX to Gemfile and bundle/, output
      assert_match /bundle add pnmx/, output
      assert_match /bundle binstubs pnmx/, output
      assert_match /Created binstub file in bin\/pnmx/, output
    end
  end

  test "init with bundle option and existing binstub" do
    Pathname.any_instance.expects(:exist?).returns(true).times(4)
    Pathname.any_instance.stubs(:mkpath)
    FileUtils.stubs(:mkdir_p)
    FileUtils.stubs(:cp_r)
    FileUtils.stubs(:cp)

    run_command("init", "--bundle").tap do |output|
      assert_match /Config file already exists in config\/deploy.yml \(remove first to create a new one\)/, output
      assert_match /Binstub already exists in bin\/pnmx \(remove first to create a new one\)/, output
    end
  end

  test "envify" do
    File.expects(:read).with(".env.erb").returns("HELLO=<%= 'world' %>")
    File.expects(:write).with(".env", "HELLO=world", perm: 0600)

    run_command("envify")
  end

  test "envify with destination" do
    File.expects(:read).with(".env.staging.erb").returns("HELLO=<%= 'world' %>")
    File.expects(:write).with(".env.staging", "HELLO=world", perm: 0600)

    run_command("envify", "-d", "staging")
  end

  test "remove with confirmation" do
    run_command("remove", "-y", config_file: "deploy_with_accessories").tap do |output|
      assert_match /docker container stop traefik/, output
      assert_match /docker container prune --force --filter label=org.opencontainers.image.title=Traefik/, output
      assert_match /docker image prune --all --force --filter label=org.opencontainers.image.title=Traefik/, output

      assert_match /docker ps --quiet --filter label=service=app | xargs docker stop/, output
      assert_match /docker container prune --force --filter label=service=app/, output
      assert_match /docker image prune --all --force --filter label=service=app/, output

      assert_match /docker container stop app-mysql/, output
      assert_match /docker container prune --force --filter label=service=app-mysql/, output
      assert_match /docker image rm --force mysql/, output
      assert_match /rm -rf app-mysql/, output

      assert_match /docker container stop app-redis/, output
      assert_match /docker container prune --force --filter label=service=app-redis/, output
      assert_match /docker image rm --force redis/, output
      assert_match /rm -rf app-redis/, output

      assert_match /docker logout/, output
    end
  end

  test "version" do
    version = stdouted { Pnmx::Cli::Main.new.version }
    assert_equal Pnmx::VERSION, version
  end

  private
    def run_command(*command, config_file: "deploy_simple")
      stdouted { Pnmx::Cli::Main.start([*command, "-c", "test/fixtures/#{config_file}.yml"]) }
    end
end
