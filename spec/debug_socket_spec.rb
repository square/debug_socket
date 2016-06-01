require "spec_helper"
require "logger"

RSpec.describe DebugSocket do
  describe ".start/.stop" do
    let(:path) { "boom.sock" }
    let(:socket) do
      10.times { sleep(1) unless File.exist?(path) }
      UNIXSocket.new(path)
    end

    before do
      DebugSocket.logger = Logger.new(StringIO.new)
      DebugSocket.start(path)
    end

    after do
      DebugSocket.stop
      10.times { sleep(1) if File.exist?(path) }
      raise "did not cleanup socket file" if File.exist?(path)
    end

    it "logs and evals input" do
      expect(DebugSocket.logger).to receive(:warn).with('[DEBUG SOCKET] "2 + 2"')
      socket.write("2 + 2")
      socket.close_write
      expect(socket.read).to eq("4\n")
    end

    it "only allows the current user to use the socket" do
      # from man 2 stat
      # 140000 = socket file
      #   0600 = u+rw
      expect(File.stat(path).mode.to_s(8)).to eq("140600")
    end

    it "can only be started once" do
      expect { DebugSocket.start("another-boom.sock") }
        .to raise_exception("debug socket thread already running")
    end

    it "catches errors in the debug socket thread" do
      allow(DebugSocket.logger).to receive(:error).and_call_original
      expect(DebugSocket.logger).to receive(:warn).with('[DEBUG SOCKET] "1"').and_raise "boom"
      expect(DebugSocket.logger).to receive(:error).with("[DEBUG SOCKET] error=#<RuntimeError: boom>")

      socket.write("1")
      socket.close_write
      expect(socket.read).to eq("")

      expect(DebugSocket.logger).to receive(:warn).with('[DEBUG SOCKET] "2"')

      another_socket = UNIXSocket.new(path)
      another_socket.write("2")
      another_socket.close_write
      expect(another_socket.read).to eq("2\n")
    end
  end

  describe ".backtrace" do
    it "returns a stacktrace for all threads" do
      running_thread = %r{thread\.object_id=#{Thread.current.object_id}\ thread\.status=run\n
        .*lib/debug_socket\.rb:\d+:in\ `backtrace'\n
        .*lib/debug_socket\.rb:\d+:in\ `block\ in\ backtrace'\n
        .*lib/debug_socket\.rb:\d+:in\ `map'\n
        .*lib/debug_socket\.rb:\d+:in\ `backtrace'\n
        .*spec/debug_socket_spec\.rb:\d+:in\ `block\ \(\d+\ levels\)\ in\ <top\ \(required\)>'}x
      thread = Thread.new { sleep 1 }
      sleep 0.1
      sleeping_thread = %r{thread\.object_id=#{thread.object_id}\ thread\.status=sleep\n
        .*spec/debug_socket_spec\.rb:\d+:in\ `sleep'\n
        .*spec/debug_socket_spec\.rb:\d+:in\ `block\ \(\d+\ levels\)\ in\ <top\ \(required\)>'}x
      bt = DebugSocket.backtrace
      expect(bt).to match(running_thread)
      expect(bt).to match(sleeping_thread)
    end
  end
end
