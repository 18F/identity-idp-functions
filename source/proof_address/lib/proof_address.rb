require 'proofer'
require 'lexisnexis'
require 'faraday'
require 'retries'

module IdentityIdpFunctions
  class ProofAddress
    def self.handle(event:, context:)
      params = JSON.parse(event['body'], symbolize_names: true)
      new(**params).proof
    end

    attr_reader :applicant_pii, :callback_url

    def initialize(applicant_pii:, callback_url:)
      @applicant_pii = applicant_pii
      @callback_url = callback_url
    end

    def proof
      proofer_result = with_retries(**retry_options) do
        lexisnexis_proofer.proof(applicant_pii)
      end

      post_callback(callback_body: {
        address_result: proofer_result.to_h,
      })
    end

    def post_callback(callback_body:)
      with_retries(**retry_options) do
        Faraday.post(
          callback_url,
          callback_body.to_json,
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
