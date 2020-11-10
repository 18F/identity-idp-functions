require 'bundler/setup' if !defined?(Bundler)
require 'json'
require 'retries'
require 'proofer'
require 'lexisnexis'
require '/opt/ruby/lib/function_helper' if !defined?(IdentityIdpFunctions::FunctionHelper)

module IdentityIdpFunctions
  class ProofAddress
    include IdentityIdpFunctions::FaradayHelper

    def self.handle(event:, context:, &callback_block) # rubocop:disable Lint/UnusedMethodArgument
      params = JSON.parse(event.to_json, symbolize_names: true)
      new(**params).proof(&callback_block)
    end

    attr_reader :applicant_pii, :callback_url

    def initialize(applicant_pii:, callback_url:)
      @applicant_pii = applicant_pii
      @callback_url = callback_url
    end

    def proof
      set_up_env!

      raise Errors::MisconfiguredLambdaError unless block_given? || api_auth_token.present?

      proofer_result = with_retries(**faraday_retry_options) do
        lexisnexis_proofer.proof(applicant_pii)
      end

      result = proofer_result.to_h
      result[:context] = { stages: [address: LexisNexis::PhoneFinder::Proofer.vendor_name] }

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
      with_retries(**faraday_retry_options) do
        build_faraday.post(
          callback_url,
          callback_body.to_json,
          'X-API-AUTH-TOKEN' => api_auth_token,
          'Content-Type' => 'application/json',
          'Accept' => 'application/json',
        )
      end
    end

    def api_auth_token
      @api_auth_token ||= ENV.fetch('IDP_API_AUTH_TOKEN') do
        ssm_helper.load('address_proof_result_token')
      end
    end

    def set_up_env!
      %w[
        lexisnexis_account_id
        lexisnexis_request_mode
        lexisnexis_username
        lexisnexis_password
        lexisnexis_base_url
        lexisnexis_phone_finder_workflow
      ].each do |env_key|
        ENV[env_key] ||= ssm_helper.load(env_key)
      end
    end

    def lexisnexis_proofer
      LexisNexis::PhoneFinder::Proofer.new
    end

    def ssm_helper
      @ssm_helper ||= SsmHelper.new
    end
  end
end
