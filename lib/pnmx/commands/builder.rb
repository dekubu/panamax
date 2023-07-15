class Pnmx::Commands::Builder < Pnmx::Commands::Base
  delegate :create, :remove, :push, :clean, :pull, :info, to: :target

  def name
    target.class.to_s.remove("Pnmx::Commands::Builder::").underscore.inquiry
  end

  def target
    case
    when !config.builder.multiarch? && !config.builder.cached?
      native
    when !config.builder.multiarch? && config.builder.cached?
      native_cached
    when config.builder.local? && config.builder.remote?
      multiarch_remote
    when config.builder.remote?
      native_remote
    else
      multiarch
    end
  end

  def native
    @native ||= Pnmx::Commands::Builder::Native.new(config)
  end

  def native_cached
    @native ||= Pnmx::Commands::Builder::Native::Cached.new(config)
  end

  def native_remote
    @native ||= Pnmx::Commands::Builder::Native::Remote.new(config)
  end

  def multiarch
    @multiarch ||= Pnmx::Commands::Builder::Multiarch.new(config)
  end

  def multiarch_remote
    @multiarch_remote ||= Pnmx::Commands::Builder::Multiarch::Remote.new(config)
  end


  def ensure_local_dependencies_installed
    if name.native?
      ensure_local_docker_installed
    else
      combine \
        ensure_local_docker_installed,
        ensure_local_buildx_installed
    end
  end

  private
    def ensure_local_docker_installed
      docker "--version"
    end

    def ensure_local_buildx_installed
      docker :buildx, "version"
    end
end
