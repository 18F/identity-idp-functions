require 'bundler/setup' if !defined?(Bundler)
require 'faraday'
require 'json'
require 'proofer'
require 'retries'
require_relative 'document_mock_client'
require '/opt/ruby/lib/faraday_helper' if !defined?(IdentityIdpFunctions::FaradayHelper)
require '/opt/ruby/lib/ssm_helper' if !defined?(IdentityIdpFunctions::SsmHelper)

module IdentityIdpFunctions
  class ProofDocumentMock
    include IdentityIdpFunctions::FaradayHelper

    def self.handle(event:, context:, &callback_block)
      params = JSON.parse(event.to_json, symbolize_names: true)
      new(**params).proof(&callback_block)
    end

    attr_reader :encryption_key, :front_image_iv, :back_image_iv, :selfie_image_iv,
                :front_image_url, :back_image_url, :selfie_image_url,
                :liveness_checking_enabled, :callback_url

    def initialize(encryption_key:,
                   front_image_iv:,
                   back_image_iv:,
                   selfie_image_iv:,
                   front_image_url:,
                   back_image_url:,
                   selfie_image_url:,
                   liveness_checking_enabled:,
                   callback_url:)
      @callback_url = callback_url
      @encryption_key = encryption_key
      @front_image_iv = front_image_iv
      @back_image_iv = back_image_iv
      @selfie_image_iv = selfie_image_iv
      @front_image_url = front_image_url
      @back_image_url = back_image_url
      @selfie_image_url = selfie_image_url
      @liveness_checking_enabled = liveness_checking_enabled
      @callback_url = callback_url
    end

    def proof(&callback_block)
      proofer_result = with_retries(**faraday_retry_options) do
        mock_proofer.proof(
          encryption_key: encryption_key,
          front_image_iv: front_image_iv,
          back_image_iv: back_image_iv,
          selfie_image_iv: selfie_image_iv,
          front_image_url: front_image_url,
          back_image_url: back_image_url,
          selfie_image_url: selfie_image_url,
          liveness_checking_enabled: liveness_checking_enabled,
          callback_url: callback_url,
        )
      end

      result = proofer_result.to_h
      result[:context] = { stages: [
        document: IdentityIdpFunctions::DocumentMockClient.vendor_name,
      ] }

      result[:exception] = proofer_result.exception.inspect if proofer_result.exception

      callback_body = {
        document_result: result,
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
        ssm_helper.load('document_proof_result_token')
      end
    end

    def ssm_helper
      @ssm_helper ||= SsmHelper.new
    end

    def mock_proofer
      IdentityIdpFunctions::DocumentMockClient.new
    end
  end
end
