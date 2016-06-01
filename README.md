# DebugSocket

A unix domain socket that listens for debug commands.


## Warning

Anything sent to the unix domain socket will be passed to `eval()`. Be careful.
Security-wise, this is ok since the debug socket is restricted to the process
owner. The socket permissions are 0600, so only the user running the process
can connect to the socket. The user that is running the process can also attach
GDB to the running process and do the same things the socket allows, only it
won't be memory safe ;).


## Usage

A rails example with puma and sidekiq:

in `config/puma.rb`

```ruby
on_worker_boot do
  DebugSocket.logger = Rails.logger
  DebugSocket.start(File.join(Dir.home, "tmp", "puma-debug-#{Process.pid}.sock"))
end
```

in `config/initializers/sidekiq.rb`

```ruby
Sidekiq.configure_server do |_config|
  DebugSocket.logger = Sidekiq::Logging.logger
  DebugSocket.start(File.join(Dir.home, "tmp", "sidekiq-debug-#{Process.pid}.sock"))
  at_exit { DebugSocket.stop }
end
```

Then in a terminal:

```
% echo backtrace | socat - UNIX-CONNECT:~/tmp/puma-debug-1234.sock
thread.object_id=70099243629020 thread.status=run
/Users/lazarus/Development/all/ruby/debug_socket/lib/debug_socket.rb:55:in `backtrace'
/Users/lazarus/Development/all/ruby/debug_socket/lib/debug_socket.rb:55:in `block in backtrace'
/Users/lazarus/Development/all/ruby/debug_socket/lib/debug_socket.rb:54:in `map'
/Users/lazarus/Development/all/ruby/debug_socket/lib/debug_socket.rb:54:in `backtrace'
/Users/lazarus/Development/all/ruby/debug_socket/spec/debug_socket_spec.rb:48:in `block (3 levels) in <top (required)>'

thread.object_id=70121809360520 thread.status=sleep
/Users/lazarus/Development/all/ruby/debug_socket/spec/debug_socket_spec.rb:48:in `sleep'
/Users/lazarus/Development/all/ruby/debug_socket/spec/debug_socket_spec.rb:48:in `block (4 levels) in <top (required)>'
```
