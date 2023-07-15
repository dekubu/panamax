class Pnmx::Cli::Prune < Pnmx::Cli::Base
  desc "all", "Prune unused images and stopped containers"
  def all
    mutating do
      containers
      images
    end
  end

  desc "images", "Prune dangling images"
  def images
    mutating do
      on(PNMX.hosts) do
        execute *PNMX.auditor.record("Pruned images"), verbosity: :debug
        execute *PNMX.prune.dangling_images
        execute *PNMX.prune.tagged_images
      end
    end
  end

  desc "containers", "Prune all stopped containers, except the last 5"
  def containers
    mutating do
      on(PNMX.hosts) do
        execute *PNMX.auditor.record("Pruned containers"), verbosity: :debug
        execute *PNMX.prune.containers
      end
    end
  end
end
