# DebugSocket

A unix domain socket that listens for debug commands.

[![Build Status](https://travis-ci.org/square/debug_socket.svg?branch=master)](https://travis-ci.org/square/debug_socket)

## Warning

Anything sent to the unix domain socket will be passed to `eval()`. Be careful.
Security-wise, this is OK: the debug socket is restricted to the process owner.
The socket permissions are 0600, so only the user running the process can
connect to the socket. The user that is running the process can also attach GDB
to the running process and do the same things the socket allows, only it won't
be memory safe ;).


## Usage

A rails example with puma and sidekiq:

in `config/puma.rb`

```ruby
on_worker_boot do
  DebugSocket.logger = Rails.logger
  DebugSocket.start(Rails.root.join("tmp", "puma-debug-#{Process.pid}.sock"))
end

on_worker_shutdown do
  DebugSocket.stop
end
```

in `config/initializers/sidekiq.rb`

```ruby
Sidekiq.configure_server do |_config|
  DebugSocket.logger = Sidekiq::Logging.logger
  # GOTCHA: if the Rails.root.join("tmp", "sidekiq-debug-#{Process.pid}.sock")
  # path is too long, this will fail. The max on Linux is 108 characters, MacOS
  # is 104. If the path is too long, try using a relative path or /tmp/<blah>.
  DebugSocket.start(Rails.root.join("tmp", "sidekiq-debug-#{Process.pid}.sock"))
  at_exit { DebugSocket.stop }
end
```

You can now send ruby instruction commands through the socket and they'll be
executed in your running process.  You can use `socat` to write and read
from the socket and dump to `stdout` like so:

```
% echo backtrace | socat - UNIX-CONNECT:~/tmp/puma-debug-1234.sock
2016-08-09T00:51:57Z puma: cluster worker 0: 1234
2016-08-09T00:51:57Z pid=1234 thread.object_id=70099243629020 thread.status=run
lib/debug_socket.rb:55:in `backtrace'
lib/debug_socket.rb:55:in `block in backtrace'
lib/debug_socket.rb:54:in `map'
lib/debug_socket.rb:54:in `backtrace'
spec/debug_socket_spec.rb:48:in `block (3 levels) in <top (required)>'

2016-08-09T00:51:57Z pid=1234 thread.object_id=70121809360520 thread.status=sleep
spec/debug_socket_spec.rb:48:in `sleep'
spec/debug_socket_spec.rb:48:in `block (4 levels) in <top (required)>'
```

The gem also provides a script.  The `debug-socket` script takes one argument,
the path to the unix socket, and it will run the `backtrace` command through
that socket.

```
% debug-socket ~/tmp/puma-debug-1234.sock
2016-08-09T00:51:57Z puma: cluster worker 0: 1234
2016-08-09T00:51:57Z pid=1234 thread.object_id=70099243629020 thread.status=run
lib/debug_socket.rb:55:in `backtrace'
lib/debug_socket.rb:55:in `block in backtrace'
lib/debug_socket.rb:54:in `map'
lib/debug_socket.rb:54:in `backtrace'
spec/debug_socket_spec.rb:48:in `block (3 levels) in <top (required)>'

2016-08-09T00:51:57Z pid=1234 thread.object_id=70121809360520 thread.status=sleep
spec/debug_socket_spec.rb:48:in `sleep'
spec/debug_socket_spec.rb:48:in `block (4 levels) in <top (required)>'
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/square/debug_socket.

If you would like to contribute code to DebugSocket, thank you! You can do so
through GitHub by forking the repository and sending a pull request. However,
before your code can be accepted into the project we need you to sign Square's
(super simple) [Individual Contributor License Agreement
(CLA)](https://spreadsheets.google.com/spreadsheet/viewform?formkey=dDViT2xzUHAwRkI3X3k5Z0lQM091OGc6MQ&ndplr=1)

## License

    Copyright 2016 Square, Inc.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
