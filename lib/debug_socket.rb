# frozen_string_literal: true

require "debug_socket/version"
require "socket"
require "time"

module DebugSocket
  @thread = nil
  @pid = nil

  def self.logger=(logger)
    @logger = logger
  end

  def self.logger
    return @logger if defined?(@logger)

    require "logger"
    @logger = Logger.new(STDERR)
  end

  def self.start(path)
    pid = Process.pid
    raise "debug socket thread already running for this process" if @thread && @pid == pid

    @pid = pid

    # make sure socket is only accessible to the process owner
    old_mask = File.umask(0o0177)

    path = path.to_s

    server = UNIXServer.new(path)
    @thread =
      Thread.new do
        loop do
          accept_attempts = 0
          socket =
            begin
              server.accept
            rescue Exception => e # rubocop:disable Lint/RescueException
              accept_attempts += 1
              logger&.error { "debug-socket-accept-error=#{e.inspect} socket attempts=#{accept_attempts} backtrace=#{e.backtrace.inspect}" }
              if server.closed?
                logger&.error("debug-socket-accept-error stopping debug socket because the socket is closed")
                break
              end

              if accept_attempts < 10
                sleep(1)
                retry
              end

              logger&.error("debug-socket-accept-error stopping debug socket after #{accept_attempts} failed accepts")
              break
            end
          input = socket.read
          logger&.unknown("debug-socket-command=#{input.inspect}")
          socket.puts(eval(input)) # rubocop:disable Security/Eval
        rescue Exception => e # rubocop:disable Lint/RescueException
          logger&.error { "debug-socket-error=#{e.inspect} backtrace=#{e.backtrace.inspect}" }
        ensure
          socket&.close
        end
      ensure
        logger&.info("debug socket shutting down path=#{path.inspect}")
        if File.exist?(path)
          File.unlink(path)
        else
          logger&.warn("the unix socket is missing, still shutting down")
        end
        @thread = nil
        @pid = nil
      end

    logger&.unknown { "Debug socket listening on #{path}" }

    @thread
  ensure
    File.umask(old_mask) if old_mask
  end

  def self.stop
    @thread&.kill
    @thread = nil
    @pid = nil
  end

  def self.backtrace
    pid = Process.pid
    "#{Time.now.utc.iso8601} #{$PROGRAM_NAME}\n" + Thread.list.map do |thread|
      output =
        +"#{Time.now.utc.iso8601} pid=#{pid} thread.object_id=#{thread.object_id} thread.status=#{thread.status}"
      backtrace = thread.backtrace || []
      output << "\n#{backtrace.join("\n")}" if backtrace
      output
    end.join("\n\n")
  end
end
