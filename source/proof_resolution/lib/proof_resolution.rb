require 'bundler/setup' if !defined?(Bundler)
require 'json'
require 'retries'
require 'proofer'
require 'aamva'
require 'lexisnexis'
require '/opt/ruby/lib/function_helper' if !defined?(IdentityIdpFunctions::FunctionHelper)

module IdentityIdpFunctions
  class ProofResolution
    include IdentityIdpFunctions::FaradayHelper
    include IdentityIdpFunctions::LoggingHelper

    def self.handle(event:, context:, &callback_block) # rubocop:disable Lint/UnusedMethodArgument
      params = JSON.parse(event.to_json, symbolize_names: true)
      new(**params).proof(&callback_block)
    end

    attr_reader :applicant_pii,
                :callback_url,
                :trace_id,
                :timer

    def initialize(
      applicant_pii:,
      callback_url:,
      should_proof_state_id:,
      dob_year_only: false,
      trace_id: nil
    )
      @applicant_pii = applicant_pii
      @callback_url = callback_url
      @should_proof_state_id = should_proof_state_id
      @dob_year_only = dob_year_only
      @trace_id = trace_id
      @timer = IdentityIdpFunctions::Timer.new
    end

    def should_proof_state_id?
      @should_proof_state_id
    end

    def dob_year_only?
      @dob_year_only
    end

    CallbackLogData = Struct.new(
      :result,
      :resolution_success,
      :state_id_success,
      keyword_init: true,
    )

    # rubocop:disable Metrics/PerceivedComplexity
    def proof
      set_up_env!

      raise Errors::MisconfiguredLambdaError if !block_given? && api_auth_token.to_s.empty?

      callback_log_data = if dob_year_only? && should_proof_state_id?
                            proof_aamva_then_lexisnexis_dob_only
                          else
                            proof_lexisnexis_then_aamva
                          end

      callback_body = {
        resolution_result: callback_log_data.result,
      }

      if block_given?
        yield callback_body
      else
        post_callback(callback_body: callback_body)
      end
    ensure
      log_event(
        name: 'ProofResolution',
        trace_id: trace_id,
        resolution_success: callback_log_data&.resolution_success,
        state_id_success: callback_log_data&.state_id_success,
        timing: timer.results,
      )
    end
    # rubocop:enable Metrics/PerceivedComplexity

    # @return [CallbackLogData]
    def proof_lexisnexis_then_aamva
      proofer_result = timer.time('resolution') do
        with_retries(**faraday_retry_options) do
          lexisnexis_proofer.proof(applicant_pii)
        end
      end

      result = proofer_result.to_h
      resolution_success = proofer_result.success?

      result[:context] = { stages: [resolution: LexisNexis::InstantVerify::Proofer.vendor_name] }
      result[:transaction_id] = proofer_result.transaction_id

      result[:timed_out] = proofer_result.timed_out?
      result[:exception] = proofer_result.exception.inspect if proofer_result.exception

      state_id_success = nil
      if should_proof_state_id? && result[:success]
        timer.time('state_id') do
          proof_state_id(result)
        end
        state_id_success = result[:success]
      end

      CallbackLogData.new(
        result: result,
        resolution_success: resolution_success,
        state_id_success: state_id_success,
      )
    end

    # @return [CallbackLogData]
    def proof_aamva_then_lexisnexis_dob_only
      proofer_result = timer.time('state_id') do
        with_retries(**faraday_retry_options) do
          aamva_proofer.proof(applicant_pii)
        end
      end

      result = proofer_result.to_h
      state_id_success = proofer_result.success?
      resolution_success = nil

      result[:context] = { stages: [{ state_id: Aamva::Proofer.vendor_name }] }

      if state_id_success
        lexisnexis_result = timer.time('resolution') do
          with_retries(**faraday_retry_options) do
            lexisnexis_proofer.proof(applicant_pii.merge(dob_year_only: dob_year_only?))
          end
        end

        resolution_success = lexisnexis_result.success?

        result.merge(lexisnexis_result.to_h) do |key, orig, current|
          key == :messages ? orig + current : current
        end

        result[:context][:stages].push(resolution: LexisNexis::InstantVerify::Proofer.vendor_name)
        result[:transaction_id] = lexisnexis_result.transaction_id
        result[:timed_out] = lexisnexis_result.timed_out?
        result[:exception] = lexisnexis_result.exception.inspect if lexisnexis_result.exception
      end

      CallbackLogData.new(
        result: result,
        resolution_success: resolution_success,
        state_id_success: state_id_success,
      )
    end

    def proof_state_id(result)
      result[:context][:stages].push(state_id: Aamva::Proofer.vendor_name)

      proofer_result = with_retries(**faraday_retry_options) do
        aamva_proofer.proof(applicant_pii)
      end

      result.merge(proofer_result.to_h) do |key, orig, current|
        key == :messages ? orig + current : current
      end

      result[:timed_out] = proofer_result.timed_out?
      result[:exception] = proofer_result.exception.inspect if proofer_result.exception

      result
    end

    def set_up_env!
      %w[
        lexisnexis_account_id
        lexisnexis_request_mode
        lexisnexis_username
        lexisnexis_password
        lexisnexis_base_url
        lexisnexis_instant_verify_workflow
        aamva_public_key
        aamva_private_key
      ].each do |env_key|
        ENV[env_key] ||= ssm_helper.load(env_key)
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

    def lexisnexis_proofer
      LexisNexis::InstantVerify::Proofer.new
    end

    def aamva_proofer
      Aamva::Proofer.new
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
