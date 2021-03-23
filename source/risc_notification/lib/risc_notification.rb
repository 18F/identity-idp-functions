require 'bundler/setup' if !defined?(Bundler)
require '/opt/ruby/lib/function_helper' if !defined?(IdentityIdpFunctions::FunctionHelper)

module IdentityIdpFunctions
  class RiscNotification
    include IdentityIdpFunctions::FaradayHelper
    include IdentityIdpFunctions::LoggingHelper

    def self.handle(event:, context:) # rubocop:disable Lint/UnusedMethodArgument
      params = JSON.parse(event.to_json, symbolize_names: true)
      new(**params).notify
    end

    attr_reader :push_notification_url, :jwt, :timer

    def initialize(push_notification_url:, jwt:)
      @push_notification_url = push_notification_url
      @jwt = jwt
      @timer = IdentityIdpFunctions::Timer.new
    end

    def notify
      response = timer.time('deliver_notification') do
        build_faraday.post(
          push_notification_url,
          jwt,
          'Accept' => 'application/json',
          'Content-Type' => 'application/secevent+jwt',
        )
      end
    ensure
      log_event(
        name: 'RiscNotification',
        response_code: response&.status,
        timing: timer.results,
      )
    end
  end
end
