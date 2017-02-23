require "debug_socket/version"
require "socket"
require "time"

module DebugSocket
  @thread = nil

  def self.logger=(logger)
    @logger = logger
  end

  def self.logger
    return @logger if defined?(@logger)
    require "logger"
    @logger = Logger.new(STDOUT)
  end

  def self.start(path)
    raise "debug socket thread already running" if @thread

    # make sure socket is only accessible to the process owner
    old_mask = File.umask(0o0177)

    @path = path.to_s

    server = UNIXServer.new(@path)
    @thread = Thread.new do
      loop do
        begin
          socket = server.accept
          input = socket.read
          logger.warn("debug-socket-command=#{input.inspect}") if logger
          socket.puts(eval(input)) # rubocop:disable Security/Eval
        rescue Exception => e # rubocop:disable Lint/RescueException
          next unless logger
          logger.error("debug-socket-error=#{e.inspect} backtrace=#{e.backtrace.inspect}")
        ensure
          socket.close
        end
      end
    end

    logger.error("Debug socket listening on #{@path}") if logger

    @thread
  ensure
    File.umask(old_mask) if old_mask
  end

  def self.stop
    @thread.kill if @thread
    File.unlink(@path) if @path && File.exist?(@path)
    @thread = nil
    @path = nil
  end

  def self.backtrace
    pid = Process.pid
    "#{Time.now.utc.iso8601} #{$PROGRAM_NAME}\n" + Thread.list.map do |thread|
      output =
        "#{Time.now.utc.iso8601} pid=#{pid} thread.object_id=#{thread.object_id} thread.status=#{thread.status}"
      backtrace = thread.backtrace || []
      output << "\n#{backtrace.join("\n")}" if backtrace
      output
    end.join("\n\n")
  end
end
