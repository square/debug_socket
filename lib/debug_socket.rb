# frozen_string_literal: true

require "debug_socket/version"
require "socket"
require "time"

module DebugSocket
  module Commands
    # When running `eval`, we don't want the input to overwrite local variables etc. `eval` runs in the current scope,
    # so we have an empty scope here that runs in a module that only has other shortcut commands the client might want
    # to run.
    def self.isolated_eval(input)
      eval(input) # rubocop:disable Security/Eval
    # We rescue Exception here because the input could have SyntaxErrors etc.
    rescue Exception => e # rubocop:disable Lint/RescueException
      DebugSocket.logger&.error { "debug-socket-error=#{e.inspect} input=#{input.inspect} path=#{@path} backtrace=#{e.backtrace.inspect}" }
      "#{e.class.name}: #{e.message}\n#{e.backtrace.join("\n")}"
    end

    # Print the backtrace for every Thread
    def self.backtrace
      pid = Process.pid
      "#{Time.now.utc.iso8601} #{$PROGRAM_NAME}\n" + Thread.list.map do |thread|
        output = "#{Time.now.utc.iso8601} pid=#{pid} thread.object_id=#{thread.object_id} thread.status=#{thread.status}"
        backtrace = thread.backtrace || []
        output << "\n#{backtrace.join("\n")}" if backtrace
        output
      end.join("\n\n")
    end
  end

  @thread = nil
  @pid = Process.pid

  def self.logger=(logger)
    @logger = logger
  end

  def self.logger
    return @logger if defined?(@logger)

    require "logger"
    @logger = Logger.new($stderr)
  end

  def self.start(path, &block)
    pid = Process.pid
    raise "debug socket thread already running for this process" if @thread && @pid == pid

    @pid = pid

    # make sure socket is only accessible to the process owner
    old_mask = File.umask(0o0177)

    @path = path.to_s

    server = UNIXServer.new(@path)
    @thread = Thread.new do
      errors = 0
      loop do
        socket = server.accept
        input = socket.read
        logger&.warn("debug-socket-command=#{input.inspect}")

        perform_audit(input, &block) if block
        socket.puts(Commands.isolated_eval(input))

        errors = 0
      rescue StandardError => e
        errors += 1
        logger&.error { "debug-socket-error=#{e.inspect} errors=#{errors} path=#{@path} backtrace=#{e.backtrace.inspect}" }
        raise e if errors > 20

        sleep(1)
      ensure
        socket&.close
      end
    rescue Exception => e # rubocop:disable Lint/RescueException
      logger&.error { "debug-socket-error=#{e.inspect} DebugSocket is broken now path=#{@path} backtrace=#{e.backtrace.inspect}" }
    end

    logger&.unknown { "Debug socket listening on #{@path}" }

    @thread
  ensure
    File.umask(old_mask) if old_mask
  end

  def self.stop
    @thread&.kill
    File.unlink(@path) if @path && File.exist?(@path)
    @thread = nil
    @pid = nil
    @path = nil
  end

  # Allow debug socket input commands to be audited by an external callback
  private_class_method def self.perform_audit(input)
    yield input
  rescue Exception => e # rubocop:disable Lint/RescueException
    logger&.error "debug-socket-error=callback unsuccessful: #{e.inspect} for #{input.inspect} path=#{@path} backtrace=#{e.backtrace.inspect}"
  end
end
