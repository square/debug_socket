require "debug_socket/version"
require "socket"

module DebugSocket
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
    old_mask = File.umask(0177)

    @path = path.to_s

    server = UNIXServer.new(@path)
    @thread = Thread.new do
      loop do
        begin
          socket = server.accept
          input = socket.read
          logger.warn("[DEBUG SOCKET] #{input.inspect}") if logger
          socket.puts(eval(input)) # rubocop:disable Lint/Eval
        rescue => e
          next unless logger
          logger.error("[DEBUG SOCKET] error=#{e.inspect}")
          logger.error(e.backtrace)
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
    Thread.list.map do |thread|
      "thread.object_id=#{thread.object_id} thread.status=#{thread.status}\n" + thread.backtrace.join("\n")
    end.join("\n\n")
  end
end
