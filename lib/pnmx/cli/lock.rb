class Pnmx::Cli::Lock < Pnmx::Cli::Base
  desc "status", "Report lock status"
  def status
    handle_missing_lock do
      on(PNMX.primary_host) { puts capture_with_debug(*PNMX.lock.status) }
    end
  end

  desc "acquire", "Acquire the deploy lock"
  option :message, aliases: "-m", type: :string, desc: "A lock message", required: true
  def acquire
    message = options[:message]
    raise_if_locked do
      on(PNMX.primary_host) { execute *PNMX.lock.acquire(message, PNMX.config.version), verbosity: :debug }
      say "Acquired the deploy lock"
    end
  end

  desc "release", "Release the deploy lock"
  def release
    handle_missing_lock do
      on(PNMX.primary_host) { execute *PNMX.lock.release, verbosity: :debug }
      say "Released the deploy lock"
    end
  end

  private
    def handle_missing_lock
      yield
    rescue LXDKit::Runner::ExecuteError => e
      if e.message =~ /No such file or directory/
        say "There is no deploy lock"
      else
        raise
      end
    end
end
