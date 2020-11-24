require 'bundler/setup'
require 'identity-idp-functions'
require 'webmock/rspec'
require 'retries'
require 'stringio'

Retries.sleep_enabled = false

Dir["#{__dir__}/support/*"].each do |support_file|
  require File.expand_path(support_file)
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:each) do
    $logger_io = StringIO.new
  end
end

# Monkeypatch to override logging to STDOUT in tests
module IdentityIdpFunctions
  module LoggingHelper
    def default_logger_io
      $logger_io
    end
  end
end
