class Pnmx::Cli::Main < Pnmx::Cli::Base
  desc "setup", "Setup all accessories and deploy app to servers"
  def setup
    print_runtime do
      mutating do
        invoke "pnmx:cli:server:bootstrap"
        invoke "pnmx:cli:accessory:boot", [ "all" ]
        deploy
      end
    end
  end

  desc "deploy", "Deploy app to servers"
  option :skip_push, aliases: "-P", type: :boolean, default: false, desc: "Skip image build and push"
  def deploy
    runtime = print_runtime do
      mutating do
        invoke_options = deploy_options

        say "Log into image registry...", :magenta
        invoke "pnmx:cli:registry:login", [], invoke_options

        if options[:skip_push]
          say "Pull app image...", :magenta
          invoke "pnmx:cli:build:pull", [], invoke_options
        else
          say "Build and push app image...", :magenta
          invoke "pnmx:cli:build:deliver", [], invoke_options
        end

        run_hook "pre-deploy"

        say "Ensure Traefik is running...", :magenta
        invoke "pnmx:cli:traefik:boot", [], invoke_options

        say "Ensure app can pass healthcheck...", :magenta
        invoke "pnmx:cli:healthcheck:perform", [], invoke_options

        say "Detect stale containers...", :magenta
        invoke "pnmx:cli:app:stale_containers", [], invoke_options

        invoke "pnmx:cli:app:boot", [], invoke_options

        say "Prune old containers and images...", :magenta
        invoke "pnmx:cli:prune:all", [], invoke_options
      end
    end

    run_hook "post-deploy", runtime: runtime.round
  end

  desc "redeploy", "Deploy app to servers without bootstrapping servers, starting Traefik, pruning, and registry login"
  option :skip_push, aliases: "-P", type: :boolean, default: false, desc: "Skip image build and push"
  def redeploy
    runtime = print_runtime do
      mutating do
        invoke_options = deploy_options

        if options[:skip_push]
          say "Pull app image...", :magenta
          invoke "pnmx:cli:build:pull", [], invoke_options
        else
          say "Build and push app image...", :magenta
          invoke "pnmx:cli:build:deliver", [], invoke_options
        end

        run_hook "pre-deploy"

        say "Ensure app can pass healthcheck...", :magenta
        invoke "pnmx:cli:healthcheck:perform", [], invoke_options

        say "Detect stale containers...", :magenta
        invoke "pnmx:cli:app:stale_containers", [], invoke_options

        invoke "pnmx:cli:app:boot", [], invoke_options
      end
    end

    run_hook "post-deploy", runtime: runtime.round
  end

  desc "rollback [VERSION]", "Rollback app to VERSION"
  def rollback(version)
    rolled_back = false
    runtime = print_runtime do
      mutating do
        invoke_options = deploy_options

        PNMX.config.version = version
        old_version = nil

        if container_available?(version)
          run_hook "pre-deploy"

          invoke "pnmx:cli:app:boot", [], invoke_options.merge(version: version)
          rolled_back = true
        else
          say "The app version '#{version}' is not available as a container (use 'pnmx app containers' for available versions)", :red
        end
      end
    end

    run_hook "post-deploy", runtime: runtime.round if rolled_back
  end

  desc "details", "Show details about all containers"
  def details
    invoke "pnmx:cli:traefik:details"
    invoke "pnmx:cli:app:details"
    invoke "pnmx:cli:accessory:details", [ "all" ]
  end

  desc "audit", "Show audit log from servers"
  def audit
    on(PNMX.hosts) do |host|
      puts_by_host host, capture_with_info(*PNMX.auditor.reveal)
    end
  end

  desc "config", "Show combined config (including secrets!)"
  def config
    run_locally do
      puts Pnmx::Utils.redacted(PNMX.config.to_h).to_yaml
    end
  end

  desc "init", "Create config stub in config/deploy.yml and env stub in .env"
  option :bundle, type: :boolean, default: false, desc: "Add PNMX to the Gemfile and create a bin/pnmx binstub"
  def init
    require "fileutils"

    if (deploy_file = Pathname.new(File.expand_path("config/deploy.yml"))).exist?
      puts "Config file already exists in config/deploy.yml (remove first to create a new one)"
    else
      FileUtils.mkdir_p deploy_file.dirname
      FileUtils.cp_r Pathname.new(File.expand_path("templates/deploy.yml", __dir__)), deploy_file
      puts "Created configuration file in config/deploy.yml"
    end

    unless (deploy_file = Pathname.new(File.expand_path(".env"))).exist?
      FileUtils.cp_r Pathname.new(File.expand_path("templates/template.env", __dir__)), deploy_file
      puts "Created .env file"
    end

    unless (hooks_dir = Pathname.new(File.expand_path(".pnmx/hooks"))).exist?
      hooks_dir.mkpath
      Pathname.new(File.expand_path("templates/sample_hooks", __dir__)).each_child do |sample_hook|
        FileUtils.cp sample_hook, hooks_dir, preserve: true
      end
      puts "Created sample hooks in .pnmx/hooks"
    end

    if options[:bundle]
      if (binstub = Pathname.new(File.expand_path("bin/pnmx"))).exist?
        puts "Binstub already exists in bin/pnmx (remove first to create a new one)"
      else
        puts "Adding PNMX to Gemfile and bundle..."
        run_locally do
          execute :bundle, :add, :pnmx
          execute :bundle, :binstubs, :pnmx
        end
        puts "Created binstub file in bin/pnmx"
      end
    end
  end

  desc "envify", "Create .env by evaluating .env.erb (or .env.staging.erb -> .env.staging when using -d staging)"
  def envify
    if destination = options[:destination]
      env_template_path = ".env.#{destination}.erb"
      env_path          = ".env.#{destination}"
    else
      env_template_path = ".env.erb"
      env_path          = ".env"
    end

    File.write(env_path, ERB.new(File.read(env_template_path)).result, perm: 0600)
  end

  desc "remove", "Remove Traefik, app, accessories, and registry session from servers"
  option :confirmed, aliases: "-y", type: :boolean, default: false, desc: "Proceed without confirmation question"
  def remove
    mutating do
      if options[:confirmed] || ask("This will remove all containers and images. Are you sure?", limited_to: %w( y N ), default: "N") == "y"
        invoke "pnmx:cli:traefik:remove", [], options.without(:confirmed)
        invoke "pnmx:cli:app:remove", [], options.without(:confirmed)
        invoke "pnmx:cli:accessory:remove", [ "all" ], options
        invoke "pnmx:cli:registry:logout", [], options.without(:confirmed)
      end
    end
  end

  desc "version", "Show PNMX version"
  def version
    puts Pnmx::VERSION
  end

  desc "accessory", "Manage accessories (db/redis/search)"
  subcommand "accessory", Pnmx::Cli::Accessory

  desc "app", "Manage application"
  subcommand "app", Pnmx::Cli::App

  desc "build", "Build application image"
  subcommand "build", Pnmx::Cli::Build

  desc "healthcheck", "Healthcheck application"
  subcommand "healthcheck", Pnmx::Cli::Healthcheck

  desc "lock", "Manage the deploy lock"
  subcommand "lock", Pnmx::Cli::Lock

  desc "prune", "Prune old application images and containers"
  subcommand "prune", Pnmx::Cli::Prune

  desc "registry", "Login and -out of the image registry"
  subcommand "registry", Pnmx::Cli::Registry

  desc "server", "Bootstrap servers with curl and Docker"
  subcommand "server", Pnmx::Cli::Server

  desc "traefik", "Manage Traefik load balancer"
  subcommand "traefik", Pnmx::Cli::Traefik

  private
    def container_available?(version)
      begin
        on(PNMX.hosts) do
          PNMX.roles_on(host).each do |role|
            container_id = capture_with_info(*PNMX.app(role: role).container_id_for_version(version))
            raise "Container not found" unless container_id.present?
          end
        end
      rescue LXDKit::Runner::ExecuteError => e
        if e.message =~ /Container not found/
          say "Error looking for container version #{version}: #{e.message}"
          return false
        else
          raise
        end
      end

      true
    end

    def deploy_options
      { "version" => PNMX.config.version }.merge(options.without("skip_push"))
    end
end
