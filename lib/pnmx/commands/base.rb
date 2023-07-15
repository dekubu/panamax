module Pnmx::Commands
  class Base
    delegate :sensitive, :argumentize, to: Pnmx::Utils

    DOCKER_HEALTH_STATUS_FORMAT = "'{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}'"
    DOCKER_HEALTH_LOG_FORMAT    = "'{{json .State.Health}}'"

    attr_accessor :config

    def initialize(config)
      @config = config
    end

    def run_over_lxd(*command, host:)
      output = "lxc exec #{host} -- sh -c".tap do |cmd|
        # if config.ssh_proxy && config.ssh_proxy.is_a?(Net::SSH::Proxy::Jump)
        #   cmd << " -J #{config.ssh_proxy.jump_proxies}"
        # elsif config.ssh_proxy && config.ssh_proxy.is_a?(Net::SSH::Proxy::Command)
        #   cmd << " -o ProxyCommand='#{config.ssh_proxy.command_line_template}'"
        # end
        cmd << " '#{command.join(" ")}'"
      end

      puts "Running: #{output}"
       
      output
    end

    def container_id_for(container_name:, only_running: false)
      docker :container, :ls, *("--all" unless only_running), "--filter", "name=^#{container_name}$", "--quiet"
    end

    private
      def combine(*commands, by: "&&")
        commands
          .compact
          .collect { |command| Array(command) + [ by ] }.flatten # Join commands
          .tap     { |commands| commands.pop } # Remove trailing combiner
      end

      def chain(*commands)
        combine *commands, by: ";"
      end

      def pipe(*commands)
        combine *commands, by: "|"
      end

      def append(*commands)
        combine *commands, by: ">>"
      end

      def write(*commands)
        combine *commands, by: ">"
      end

      def xargs(command)
        [ :xargs, command ].flatten
      end

      def docker(*args)
        args.compact.unshift :docker
      end

      def tags(**details)
        Pnmx::Tags.from_config(config, **details)
      end
  end
end
