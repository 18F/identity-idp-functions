require 'proofer'
require 'lexisnexis'
require 'faraday'

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
      proofer_result = LexisNexis::PhoneFinder::Proofer.new.proof(applicant_pii)

      post_callback(callback_body: {
        address_result: proofer_result.to_h,
      })
    end

    def post_callback(callback_body:)
      connection = Faraday.new do |faraday|
        faraday.request :retry, retry_options
      end

      connection.post(
        callback_url,
        callback_body.to_json,
        "Content-Type" => 'application/json',
        "Accept" => 'application/json'
      )
    end

    def retry_options
      {
        max: 2,
        interval: 0.05,
        interval_randomness: 0.5,
        backoff_factor: 2
      }
    end
  end
end
