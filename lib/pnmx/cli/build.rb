class Pnmx::Cli::Build < Pnmx::Cli::Base
  class BuildError < StandardError; end

  desc "deliver", "Build app and push app image to registry then pull image on servers"
  def deliver
    mutating do
      push
      pull
    end
  end

  desc "push", "Build and push app image to registry"
  def push
    mutating do
      cli = self

      verify_local_dependencies
      run_hook "pre-build"

      run_locally do
        begin
          PNMX.with_verbosity(:debug) { execute *PNMX.builder.push }
        rescue SSHKit::Command::Failed => e
          if e.message =~ /(no builder)|(no such file or directory)/
            error "Missing compatible builder, so creating a new one first"

            if cli.create
              PNMX.with_verbosity(:debug) { execute *PNMX.builder.push }
            end
          else
            raise
          end
        end
      end
    end
  end

  desc "pull", "Pull app image from registry onto servers"
  def pull
    mutating do
      on(PNMX.hosts) do
        execute *PNMX.auditor.record("Pulled image with version #{PNMX.config.version}"), verbosity: :debug
        execute *PNMX.builder.clean, raise_on_non_zero_exit: false
        execute *PNMX.builder.pull
      end
    end
  end

  desc "create", "Create a build setup"
  def create
    mutating do
      run_locally do
        begin
          debug "Using builder: #{PNMX.builder.name}"
          execute *PNMX.builder.create
        rescue SSHKit::Command::Failed => e
          if e.message =~ /stderr=(.*)/
            error "Couldn't create remote builder: #{$1}"
            false
          else
            raise
          end
        end
      end
    end
  end

  desc "remove", "Remove build setup"
  def remove
    mutating do
      run_locally do
        debug "Using builder: #{PNMX.builder.name}"
        execute *PNMX.builder.remove
      end
    end
  end

  desc "details", "Show build setup"
  def details
    run_locally do
      puts "Builder: #{PNMX.builder.name}"
      puts capture(*PNMX.builder.info)
    end
  end

  private
    def verify_local_dependencies
      run_locally do
        begin
          execute *PNMX.builder.ensure_local_dependencies_installed
        rescue SSHKit::Command::Failed => e
          build_error = e.message =~ /command not found/ ?
            "Docker is not installed locally" :
            "Docker buildx plugin is not installed locally"

          raise BuildError, build_error
        end
      end
    end
end
