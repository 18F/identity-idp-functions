require 'bundler/setup' if !defined?(Bundler)
require 'faraday'
require 'json'
require 'proofer'
require 'retries'
require_relative 'address_mock_client'
require '/opt/ruby/lib/ssm_helper' if !defined?(IdentityIdpFunctions::SsmHelper)

module IdentityIdpFunctions
  class ProofAddressMock
    def self.handle(event:, context:, &callback_block)
      params = JSON.parse(event.to_json, symbolize_names: true)
      new(**params).proof(&callback_block)
    end

    attr_reader :applicant_pii, :callback_url

    def initialize(applicant_pii:, callback_url:)
      @applicant_pii = applicant_pii
      @callback_url = callback_url
    end

    def proof(&callback_block)
      proofer_result = with_retries(**retry_options) do
        mock_proofer.proof(applicant_pii)
      end

      result = proofer_result.to_h
      result[:context] = { stages: [
        address: IdentityIdpFunctions::AddressMockClient.vendor_name
      ] }

      result[:timed_out] = proofer_result.timed_out?
      result[:exception] = proofer_result.exception.inspect if proofer_result.exception

      callback_body = {
        address_result: result,
      }

      if block_given?
        yield callback_body
      else
        post_callback(callback_body: callback_body)
      end
    end

    def post_callback(callback_body:)
      with_retries(**retry_options) do
        Faraday.post(
          callback_url,
          callback_body.to_json,
          "X-API-AUTH-TOKEN" => api_auth_token,
          "Content-Type" => 'application/json',
          "Accept" => 'application/json'
        )
      end
    end

    def api_auth_token
      @api_auth_token ||= ENV.fetch("IDP_API_AUTH_TOKEN") do
        ssm_helper.load('address_proof_result_token')
      end
    end

    def ssm_helper
      @ssm_helper ||= SsmHelper.new
    end

    def mock_proofer
      IdentityIdpFunctions::AddressMockClient.new
    end

    def retry_options
      {
        max_tries: 3,
        rescue: [Faraday::TimeoutError, Faraday::ConnectionFailed],
      }
    end
  end
end
