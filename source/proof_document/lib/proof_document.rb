require 'bundler/setup' if !defined?(Bundler)
require 'faraday'
require 'json'
require 'retries'
require '/opt/ruby/lib/faraday_helper' if !defined?(IdentityIdpFunctions::FaradayHelper)
require '/opt/ruby/lib/ssm_helper' if !defined?(IdentityIdpFunctions::SsmHelper)
require 'openssl'
require 'aws-sdk-s3'

module IdentityIdpFunctions
  class ProofDocument
    include IdentityIdpFunctions::FaradayHelper

    def self.handle(event:, context:, &callback_block) # rubocop:disable Lint/UnusedMethodArgument
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

    def proof(&callback_block) # rubocop:disable Lint/UnusedMethodArgument
      proofer_result = with_retries(**faraday_retry_options) do
        document_proofer.post_images(
          front_image: decrypt_from_s3(front_image_url, front_image_iv),
          back_image: decrypt_from_s3(back_image_url, back_image_iv),
          selfie_image: \
            liveness_checking_enabled ? decrypt_from_s3(selfie_image_url, selfie_image_iv) : '',
          liveness_checking_enabled: liveness_checking_enabled,
        )
      end

      result = proofer_result.to_h

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

    def document_proofer
      IdentityDocAuth::Acuant::AcuantClient.new(
        assure_id_password: ssm_helper.load('acuant_assure_id_password'),
        assure_id_subscription_id: ssm_helper.load('acuant_assure_id_subscription_id'),
        assure_id_url: ssm_helper.load('acuant_assure_id_url'),
        assure_id_username: ssm_helper.load('acuant_assure_id_username'),
        facial_match_url: ssm_helper.load('acuant_facial_match_url'),
        passlive_url: ssm_helper.load('acuant_passlive_url'),
        timeout: ssm_helper.load('acuant_timeout'),
      )
    end

    def ssm_helper
      @ssm_helper ||= SsmHelper.new
    end

    private

    def s3_client
      @s3_client ||= Aws::S3::Client.new(
        http_open_timeout: 5,
        http_read_timeout: 5,
      )
    end

    def decrypt_from_s3(url, iv)
      encrypted_image = fetch_file(url)
      decrypt(encrypted_image, iv)
    end

    def fetch_file(url)
      uri = URI.parse(url)
      document_bucket = uri.host.gsub('.amazonaws.com', '')
      resp = s3_client.get_object(bucket: document_bucket, key: uri.path[1..-1])
      resp.body.read
    end

    def decrypt(encrypted_image, iv)
      cipher = OpenSSL::Cipher.new('aes-256-gcm')
      cipher.decrypt
      cipher.iv = iv
      cipher.key = encryption_key
      cipher.auth_data = ''
      cipher.auth_tag = encrypted_image[-16..-1]

      cipher.update(encrypted_image[0..-17]) + cipher.final
    end
  end
end
