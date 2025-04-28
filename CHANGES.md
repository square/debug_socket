### 0.1.9 2025-04-03

- [#17](https://github.com/square/debug_socket/pull/17)
  Refactor error handling. Previously all errors (including `eval` errors) were caught in the same `rescue Exception`.
  Now, we only `rescue Exception` for `eval` errors. For `DebugSocket` errors, we only `rescue StandardError` and we
  allow 20 consecutive errors before `DebugSocket` gives up and dies permanently.
  (@nerdrew)

- [#16](https://github.com/square/debug_socket/pull/16)
  Allow external auditing of debug sessions.
  (@doctown)

### 0.1.8 2022-10-10

- [#15](https://github.com/square/debug_socket/pull/15)
  Remove socat dependency in debug-socket script.

### 0.1.7 2020-01-09

- [#11](https://github.com/square/debug_socket/pull/11)
  Properly escape command when sent to socket.
  ([@drcapulet])

### 0.1.6 2018-09-20
- Update rubocop
- Check socket existence before closing

### 0.1.5 2017-09-07
- Cleanup logging

### 0.1.4 2017-03-17
- Allow forked children to open their own debug sockets

### 0.1.3 2017-02-23
- Handle syntax errors (and other errors that do not inherit from StandardError) in eval.
- Cleanup logging and change log message format

### 0.1.2 2016-08-24
- Initial Release
