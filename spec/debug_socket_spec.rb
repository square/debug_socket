# frozen_string_literal: true

RSpec.describe DebugSocket do
  describe ".start/.stop" do
    let(:path) do
      100.times do
        tmp = "boom-#{rand(0..100)}.sock"
        return tmp unless File.exist?(tmp)
      end
      raise "Couldn't find an unused socket"
    end
    let(:log_buffer) { StringIO.new }

    before do
      DebugSocket.logger = Logger.new(log_buffer)
      DebugSocket.start(path)
      20.times { sleep(0.1) unless File.exist?(path) }
    end

    after do
      DebugSocket.stop
      20.times { sleep(0.1) if File.exist?(path) }
      puts log_buffer.string
      raise "did not cleanup socket file" if File.exist?(path)
    end

    it "logs and evals input" do
      socket = UNIXSocket.new(path)
      socket.write("2 + 2")
      socket.close_write
      expect(socket.read).to eq("4\n")
      expect(log_buffer.string).to include('debug-socket-command="2 + 2"')
    end

    it "only allows the current user to use the socket" do
      # from man 2 stat
      # 140000 = socket file
      #   0600 = u+rw
      expect(File.stat(path).mode.to_s(8)).to eq("140600")
    end

    it "can only be started once per process" do
      expect { DebugSocket.start("another-boom.sock") }
        .to raise_exception("debug socket thread already running for this process")
    end

    if Process.respond_to?(:fork)
      it "can only be started once per process, including in forked children" do
        another_path = "another-boom.sock"

        if (child = fork)
          expect { DebugSocket.start(another_path) }
            .to raise_exception("debug socket thread already running for this process")

          20.times { sleep(0.1) unless File.exist?(another_path) }
          # make sure the child was able to start DebugSocket
          another_socket = UNIXSocket.new(another_path)
          another_socket.write("2 + 2")
          another_socket.close_write
          expect(another_socket.read).to eq("4\n")
          Process.wait(child)
        else
          begin
            DebugSocket.logger = Logger.new(STDERR)
            DebugSocket.start(another_path)
            sleep(1)
            DebugSocket.stop
          ensure
            File.unlink(another_path) if File.exist?(another_path)
            exit!
          end
        end
      end

      it "only cleans up it's own socket in a child process" do
        if (child = fork)
          sleep(0.1)
          Process.wait(child)
          socket = UNIXSocket.new(path)
          socket.write("2 + 2")
          socket.close_write
          expect(socket.read).to eq("4\n")
          expect(log_buffer.string).to include('debug-socket-command="2 + 2"')
        else
          begin
            DebugSocket.stop
          ensure
            exit!
          end
        end
      end
    end

    it "catches errors in the debug socket thread" do
      socket = UNIXSocket.new(path)
      socket.write("asdf}(]")
      socket.close_write
      expect(socket.read).to eq("")

      another_socket = UNIXSocket.new(path)
      another_socket.write("2")
      another_socket.close_write
      expect(another_socket.read).to eq("2\n")

      expect(log_buffer.string).to include("debug-socket-error=#<SyntaxError: (eval):1: syntax error")
      expect(log_buffer.string).to include('debug-socket-command="2"')
    end

    it "catches accept errors and stop debug socket" do
      ObjectSpace.each_object(UNIXServer).each(&:close)
      begin
        UNIXSocket.new(path)
        raise "expected an exception, but no exception was raised"
      rescue IOError, Errno::ENOENT # rubocop:disable Lint/HandleExceptions
      end
      expect(log_buffer.string).to include("debug-socket-accept-error")
    end
  end

  describe ".backtrace" do
    it "returns a stacktrace for all threads" do
      time_pid = "\\d{4}-\\d\\d-\\d\\dT\\d\\d:\\d\\d:\\d\\dZ\\ pid=#{Process.pid}"
      running_thread = %r{#{time_pid}\ thread\.object_id=#{Thread.current.object_id}\ thread\.status=run\n
        .*lib/debug_socket\.rb:\d+:in\ `(block\ in\ )?backtrace'\n # jruby adds the "block in" part
        .*lib/debug_socket\.rb:\d+:in\ `block\ in\ backtrace'\n
        .*lib/debug_socket\.rb:\d+:in\ `map'\n
        .*lib/debug_socket\.rb:\d+:in\ `backtrace'\n
        .*spec/debug_socket_spec\.rb:\d+:in\ `block.*'}x
      thread = Thread.new { sleep 1 }
      sleep 0.1
      sleeping_thread = %r{#{time_pid}\ thread\.object_id=#{thread.object_id}\ thread\.status=sleep\n
        .*spec/debug_socket_spec\.rb:\d+:in\ `(block\ in\ )?sleep'\n # jruby adds the "block in" part
        .*spec/debug_socket_spec\.rb:\d+:in\ `block.*'}x
      bt = DebugSocket.backtrace
      expect(bt).to match(running_thread)
      expect(bt).to match(sleeping_thread)
    end
  end

  describe "stress test", slow: true do
    it "works with lots of threads, even in jruby" do
      threads = Array.new(10) do
        Thread.new { 100.times { Thread.new { sleep(0.001) }.join } }
      end

      expect do
        DebugSocket.backtrace while threads.any?(&:alive?)
        threads.join
        threads.map(&:value)
      end.not_to raise_exception
    end
  end
end
