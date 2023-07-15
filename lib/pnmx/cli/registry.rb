class Pnmx::Cli::Registry < Pnmx::Cli::Base
  desc "login", "Log in to registry locally and remotely"
  def login
    run_locally    { execute *PNMX.registry.login }
    on(PNMX.hosts) { execute *PNMX.registry.login }
  # FIXME: This rescue needed?
  rescue ArgumentError => e
    puts e.message
  end

  desc "logout", "Log out of registry remotely"
  def logout
    on(PNMX.hosts) { execute *PNMX.registry.logout }
  # FIXME: This rescue needed?
  rescue ArgumentError => e
    puts e.message
  end
end
