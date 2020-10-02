require 'proofer'
require 'lexisnexis'
require 'faraday'
require 'retries'

module IdentityIdpFunctions
  class ProofAddress
    def self.handle(event:, context:, &callback_block)
      params = JSON.parse(event['body'], symbolize_names: true)
      new(
        idp_api_auth_token: ENV.fetch("IDP_API_AUTH_TOKEN"),
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
        lexisnexis_proofer.proof(applicant_pii)
      end

      callback_body = {
        address_result: proofer_result.to_h,
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

    def lexisnexis_proofer
      LexisNexis::PhoneFinder::Proofer.new
    end

    def retry_options
      {
        max_tries: 3,
        rescue: [Faraday::TimeoutError, Faraday::ConnectionFailed],
      }
    end
  end
end
