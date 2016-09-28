require "spec_helper"
require "logger"

RSpec.describe DebugSocket do
  let(:path) { "boom-#{rand(0..100)}.sock" }
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

  it "logs commands" do
    expect(DebugSocket.logger).to receive(:warn).with("[DEBUG SOCKET] \"boom\"")
    socket.write("boom")
    socket.close_write
    expect(socket.read).to eq("Unsupported command: \"boom\"\n")
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
    expect(DebugSocket.logger).to receive(:warn).with('[DEBUG SOCKET] "foo"').and_raise "boom"
    expect(DebugSocket.logger).to receive(:error).with("[DEBUG SOCKET] error=#<RuntimeError: boom>")

    socket.write("foo")
    socket.close_write
    expect(socket.read).to eq("")

    expect(DebugSocket.logger).to receive(:warn).with('[DEBUG SOCKET] "boo"')

    another_socket = UNIXSocket.new(path)
    another_socket.write("boo")
    another_socket.close_write
    expect(another_socket.read).to eq("Unsupported command: \"boo\"\n")
  end

  describe "backtrace" do
    it "returns a stacktrace for all threads" do
      time_pid = "\\d{4}-\\d\\d-\\d\\dT\\d\\d:\\d\\d:\\d\\dZ\\ pid=#{Process.pid}"
      running_thread = %r{#{time_pid}\ thread\.object_id=\d+\ thread\.status=run\n
        .*lib/debug_socket\.rb:\d+:in\ `backtrace'\n
        .*lib/debug_socket\.rb:\d+:in\ `block\ in\ backtrace'\n
        .*lib/debug_socket\.rb:\d+:in\ `map'\n
        .*lib/debug_socket\.rb:\d+:in\ `backtrace'}x
      thread = Thread.new { sleep 1 }
      sleep 0.1
      sleeping_thread = %r{#{time_pid}\ thread\.object_id=#{thread.object_id}\ thread\.status=sleep\n
        .*spec/debug_socket_spec\.rb:\d+:in\ `sleep'\n
        .*spec/debug_socket_spec\.rb:\d+:in\ `block.*'}x
      socket.write("backtrace")
      socket.close_write
      bt = socket.read
      expect(bt).to match(running_thread)
      expect(bt).to match(sleeping_thread)
    end
  end

  describe "stress test" do
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
