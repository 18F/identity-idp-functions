require 'proofer'
require 'faraday'
require 'retries'
require_relative 'resolution_mock_client'
require_relative 'state_id_mock_client'

module IdentityIdpFunctions
  class ProofResolutionMock
    def self.handle(event:, context:, &callback_block)
      params = JSON.parse(event['body'], symbolize_names: true)
      new(**params).proof(&callback_block)
    end

    attr_reader :applicant_pii, :callback_url, :should_proof_state_id

    def initialize(applicant_pii:, callback_url:, should_proof_state_id:)
      @applicant_pii = applicant_pii
      @callback_url = callback_url
      @should_proof_state_id = should_proof_state_id
    end

    def proof(&callback_block)
      proofer_result = with_retries(**retry_options) do
        resolution_mock_proofer.proof(applicant_pii)
      end

      result = proofer_result.to_h
      result[:context] = { stages: [
        resolution: IdentityIdpFunctions::ResolutionMockClient.vendor_name
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
        post_callback(callback_body: callback_body)
      end
    end

    def proof_state_id(result)
      result[:context][:stages].push(state_id: IdentityIdpFunctions::StateIdMockClient.vendor_name)

      proofer_result = with_retries(**retry_options) do
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
      with_retries(**retry_options) do
        Faraday.post(
          callback_url,
          callback_body.to_json,
          "X-API-AUTH-TOKEN" => ENV.fetch('IDP_API_AUTH_TOKEN'),
          "Content-Type" => 'application/json',
          "Accept" => 'application/json'
        )
      end
    end

    def resolution_mock_proofer
      IdentityIdpFunctions::ResolutionMockClient.new
    end

    def state_id_mock_proofer
      IdentityIdpFunctions::StateIdMockClient.new
    end

    def retry_options
      {
        max_tries: 3,
        rescue: [Faraday::TimeoutError, Faraday::ConnectionFailed],
      }
    end
  end
end
