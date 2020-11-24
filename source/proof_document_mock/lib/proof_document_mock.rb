require 'bundler/setup' if !defined?(Bundler)
require 'faraday'
require 'json'
require 'proofer'
require 'retries'
require_relative 'document_mock_client'
require '/opt/ruby/lib/function_helper' if !defined?(IdentityIdpFunctions::FunctionHelper)

module IdentityIdpFunctions
  class ProofDocumentMock
    include IdentityIdpFunctions::FaradayHelper
    include IdentityIdpFunctions::LoggingHelper

    def self.handle(event:, context:, &callback_block) # rubocop:disable Lint/UnusedMethodArgument
      params = JSON.parse(event.to_json, symbolize_names: true)
      new(**params).proof(&callback_block)
    end

    attr_reader :encryption_key, :front_image_iv, :back_image_iv, :selfie_image_iv,
                :front_image_url, :back_image_url, :selfie_image_url,
                :liveness_checking_enabled, :callback_url, :trace_id, :timer

    def initialize(encryption_key:,
                   front_image_iv:,
                   back_image_iv:,
                   selfie_image_iv:,
                   front_image_url:,
                   back_image_url:,
                   selfie_image_url:,
                   liveness_checking_enabled:,
                   callback_url:,
                   trace_id: nil)
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
      @trace_id = trace_id
      @timer = IdentityIdpFunctions::Timer.new
    end

    def proof(&callback_block) # rubocop:disable Lint/UnusedMethodArgument
      proofer_result = timer.time('proof_documents') do
        with_retries(**faraday_retry_options) do
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
        timer.time('callback') do
          post_callback(callback_body: callback_body)
        end
      end
    ensure
      log_event(
        name: 'ProofDocumentMock',
        trace_id: trace_id,
        success: proofer_result&.success?,
        timing: timer.results,
      )
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
