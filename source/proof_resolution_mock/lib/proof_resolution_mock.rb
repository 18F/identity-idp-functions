require 'bundler/setup' if !defined?(Bundler)
require 'json'
require 'retries'
require 'proofer'
require_relative 'resolution_mock_client'
require_relative 'state_id_mock_client'
require '/opt/ruby/lib/function_helper' if !defined?(IdentityIdpFunctions::FunctionHelper)

module IdentityIdpFunctions
  class ProofResolutionMock
    include IdentityIdpFunctions::FaradayHelper
    include IdentityIdpFunctions::LoggingHelper

    def self.handle(event:, context:, &callback_block) # rubocop:disable Lint/UnusedMethodArgument
      params = JSON.parse(event.to_json, symbolize_names: true)
      new(**params).proof(&callback_block)
    end

    attr_reader :applicant_pii, :callback_url, :should_proof_state_id, :trace_id, :timer

    def initialize(applicant_pii:, callback_url:, should_proof_state_id:, trace_id: nil)
      @applicant_pii = applicant_pii
      @callback_url = callback_url
      @should_proof_state_id = should_proof_state_id
      @trace_id = trace_id
      @timer = IdentityIdpFunctions::Timer.new
    end

    def proof
      raise Errors::MisconfiguredLambdaError if !block_given? && api_auth_token.to_s.empty?

      proofer_result = with_retries(**faraday_retry_options) do
        resolution_mock_proofer.proof(applicant_pii)
      end

      result = proofer_result.to_h
      result[:context] = { stages: [
        resolution: IdentityIdpFunctions::ResolutionMockClient.vendor_name,
      ] }

      result[:timed_out] = proofer_result.timed_out?
      result[:exception] = proofer_result.exception.inspect if proofer_result.exception

      if should_proof_state_id && result[:success]
        proof_state_id(result)
      end

      callback_body = {
        resolution_result: result,
      }

      if block_given?
        yield callback_body
      else
        timer.time('callback') do
          post_callback(callback_body: callback_body)
        end
      end

      log_event(
        name: 'ProofResolutionMock',
        trace_id: trace_id,
        success: proofer_result.success?,
        timing: timer.results
      )
    end

    def proof_state_id(result)
      result[:context][:stages].push(state_id: IdentityIdpFunctions::StateIdMockClient.vendor_name)

      proofer_result = with_retries(**faraday_retry_options) do
        state_id_mock_proofer.proof(applicant_pii)
      end

      result.merge(proofer_result.to_h) do |key, orig, current|
        key == :messages ? orig + current : current
      end

      result[:timed_out] = proofer_result.timed_out?
      result[:exception] = proofer_result.exception.inspect if proofer_result.exception

      result
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

    def resolution_mock_proofer
      IdentityIdpFunctions::ResolutionMockClient.new
    end

    def state_id_mock_proofer
      IdentityIdpFunctions::StateIdMockClient.new
    end

    def api_auth_token
      @api_auth_token ||= ENV.fetch('IDP_API_AUTH_TOKEN') do
        ssm_helper.load('resolution_proof_result_token')
      end
    end

    def ssm_helper
      @ssm_helper ||= SsmHelper.new
    end
  end
end
