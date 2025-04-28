# frozen_string_literal: true

require "bundler/setup"
require "debug_socket"
require "io/wait"
require "pry-byebug"

RSpec.configure do |_config|
  def almost_there(retries = 100)
    yield
  rescue RSpec::Expectations::ExpectationNotMetError
    raise if retries < 1

    sleep 0.1
    retries -= 1
    retry
  end
end
