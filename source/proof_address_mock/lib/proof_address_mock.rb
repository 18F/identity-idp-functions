require 'proofer'
require 'faraday'
require 'retries'
require 'identity-idp-functions/mock_proofers/address_mock'

module IdentityIdpFunctions
  class ProofAddressMock
    def self.handle(event:, context:, &callback_block)
      params = JSON.parse(event['body'], symbolize_names: true)
      new(
        idp_api_auth_token: ENV['IDP_API_AUTH_TOKEN'],
        **params,
      ).proof(&callback_block)
    end

    attr_reader :applicant_pii, :callback_url, :idp_api_auth_token

    def initialize(applicant_pii:, callback_url:, idp_api_auth_token:)
      @applicant_pii = applicant_pii
      @callback_url = callback_url
      @idp_api_auth_token = idp_api_auth_token
    end

    def proof(&callback_block)
      proofer_result = with_retries(**retry_options) do
        mock_proofer.proof(applicant_pii)
      end

      result = proofer_result.to_h
      result[:context] = { stages: [address: IdentityIdpFunctions::MockProofers::AddressMock.inspect] }
      result[:timed_out] = proofer_result.timed_out?

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
          "X-API-AUTH-TOKEN" => idp_api_auth_token,
          "Content-Type" => 'application/json',
          "Accept" => 'application/json'
        )
      end
    end

    def mock_proofer
      IdentityIdpFunctions::MockProofers::AddressMock.new
    end

    def retry_options
      {
        max_tries: 3,
        rescue: [Faraday::TimeoutError, Faraday::ConnectionFailed],
      }
    end
  end
end
