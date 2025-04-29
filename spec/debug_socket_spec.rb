# frozen_string_literal: true

require "logger"

RSpec.describe DebugSocket do
  describe ".start/.stop" do
    let(:path) do
      100.times do
        tmp = "boom-#{rand(0..100)}.sock"
        return tmp unless File.exist?(tmp)
      end
      raise "Couldn't find an unused socket"
    end
    let(:socket) do
      10.times { sleep(1) unless File.exist?(path) }
      UNIXSocket.new(path)
    end
    let(:log_buffer) { StringIO.new }

    before do
      DebugSocket.logger = Logger.new(log_buffer)
      DebugSocket.start(path)
    end

    def write(str, socket_path = path)
      20.times { sleep(0.1) unless File.exist?(socket_path) }
      socket = UNIXSocket.new(socket_path)

      raise "Socket write timeout=#{socket_path}" unless socket.wait_writable(1)

      socket.write(str)
      socket.close_write

      raise "Socket read timeout=#{socket_path}" unless socket.wait_readable(1)

      socket.read
    end

    after do
      DebugSocket.stop
      10.times { sleep(1) if File.exist?(path) }
      raise "did not cleanup socket file" if File.exist?(path)
    end

    it "logs and evals input" do
      expect(write("2 + 2")).to eq("4\n")
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

          expect(write("Thread.list.each(&:wakeup)", another_path)).to match(/Thread/)
          Process.wait(child, Process::WNOHANG)
        else
          begin
            DebugSocket.start(another_path)
            sleep
            sleep(1)
            DebugSocket.stop
          ensure
            exit!(1)
          end
        end
      end
    end

    it "catches errors in the debug socket thread" do
      expect(write("asdf}(]")).to include("SyntaxError")
      expect(write("2")).to eq("2\n")

      expect(log_buffer.string).to match(/debug-socket-error=#<SyntaxError:.*eval.*syntax error/)
      expect(log_buffer.string).to include('debug-socket-command="2"')
    end

    it "isolates the eval from the local scope" do
      expect(write("server = 1")).to eq("1\n")
      expect(write("server = 1")).to eq("1\n")
    end

    it "retries socket errors 10 times then dies" do
      20.times { sleep(0.1) unless File.exist?(path) }

      slept = false
      allow(DebugSocket).to receive(:sleep).and_wrap_original do |original, delay|
        next if slept

        slept = true
        original.call(delay)
      end

      socket = UNIXSocket.new(path)
      socket.write("sleep(1)")
      socket.close

      20.times do
        socket = UNIXSocket.new(path)
        socket.close
      end

      almost_there(250) do
        (1..20).each { |i| expect(log_buffer.string).to include("errors=#{i + 1}") }
        expect(log_buffer.string).to include("DebugSocket is broken now")
      end
    end

    context "with proc" do
      before do
        DebugSocket.stop
      end

      it "calls the audit proc with the input" do
        audit_calls = []
        audit_proc = proc { |input| audit_calls << input }

        DebugSocket.start(path, &audit_proc)
        expect(write("2 + 2")).to eq("4\n")
        expect(audit_calls).to eq(["2 + 2"])
      end

      it "does not raise if the audit proc raises, and still processes the command" do
        audit_proc = proc { |_input| raise "audit error" }

        DebugSocket.start(path, &audit_proc)

        expect(write("3 + 3")).to eq("6\n")
        # No error should be raised to the client, and the command is processed
        expect(log_buffer.string).to include('debug-socket-error=callback unsuccessful: #<RuntimeError: audit error> for "3 + 3"')
      end
    end

    describe "Commands.backtrace" do
      it "returns a stacktrace for all threads" do
        time_pid = "\\d{4}-\\d\\d-\\d\\dT\\d\\d:\\d\\d:\\d\\dZ\\ pid=#{Process.pid}"
        running_thread = %r{#{time_pid}\ thread\.object_id=\d+\ thread\.status=run\n
          .*lib/debug_socket\.rb:\d+:in\ .*backtrace'\n
          .*lib/debug_socket\.rb:\d+:in\ .*block\ in.*backtrace'\n
          .*lib/debug_socket\.rb:\d+:in\ .*map'\n
          .*lib/debug_socket\.rb:\d+:in\ .*backtrace'}x
        thread = Thread.new { sleep 1 }
        sleep 0.1
        sleeping_thread = %r{#{time_pid}\ thread\.object_id=#{thread.object_id}\ thread\.status=sleep\n
          .*spec/debug_socket_spec\.rb:\d+:in\ .*sleep'\n
          .*spec/debug_socket_spec\.rb:\d+:in\ .*block.*'}x
        bt = write("backtrace")
        expect(bt).to match(running_thread)
        expect(bt).to match(sleeping_thread)
      end
    end
  end
end
