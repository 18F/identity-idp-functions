require 'securerandom'
require 'identity-idp-functions/proof_resolution'

RSpec.describe IdentityIdpFunctions::ProofResolution do
  let(:idp_api_auth_token) { SecureRandom.hex }
  let(:callback_url) { 'https://example.login.gov/api/callbacks/proof-resolution/:token' }
  let(:trace_id) { SecureRandom.uuid }
  let(:applicant_pii) do
    {
      first_name: 'Johnny',
      last_name: 'Appleseed',
      uuid: SecureRandom.hex,
      address1: '123 Main St.',
      city: 'Milwaukee',
      state: 'WI',
      dob: '01/01/1970',
      ssn: '123456789',
      zipcode: '53206',
      phone: '18888675309',
      state_id_number: '123456',
      state_id_type: 'drivers_license',
      state_id_jurisdiction: 'WI',
    }
  end

  before do
    stub_const(
      'ENV',
      'IDP_API_AUTH_TOKEN' => idp_api_auth_token,
      'lexisnexis_account_id' => 'abc123',
      'lexisnexis_request_mode' => 'aaa',
      'lexisnexis_username' => 'aaa',
      'lexisnexis_password' => 'aaa',
      'lexisnexis_base_url' => 'https://lexisnexis.example.com/',
      'lexisnexis_instant_verify_workflow' => 'aaa',
      'aamva_public_key' => 'aamvamaa',
      'aamva_private_key' => 'aamvamaa',
    )
  end

  describe '.handle' do
    before do
      stub_request(
        :post,
        'https://lexisnexis.example.com/restws/identity/v2/abc123/aaa/conversation',
      ).to_return(body: lexisnexis_response.to_json)

      stub_request(:post, Aamva::Request::VerificationRequest.verification_url).
        to_return(body: {}.to_json, status: 200)

      stub_request(:post, callback_url).
        with(
          headers: {
            'Content-Type' => 'application/json',
            'X-API-AUTH-TOKEN' => idp_api_auth_token,
          },
        ) do |request|
        expect(JSON.parse(request.body, symbolize_names: true)).to match(expected_callback_response)
      end
    end

    let(:lexisnexis_response) do
      { 'Status' => { 'TransactionStatus' => 'passed' } }
    end

    let(:expected_callback_response) do
      {
        resolution_result: {
          exception: nil,
          errors: {},
          messages: [],
          success: true,
          timed_out: false,
          context: { stages: [
            { resolution: LexisNexis::InstantVerify::Proofer.vendor_name },
            { state_id: Aamva::Proofer.vendor_name },
          ] },
          transaction_id: nil,
        },
      }
    end

    let(:dob_year_only) { false }
    let(:event) do
      {
        callback_url: callback_url,
        should_proof_state_id: true,
        applicant_pii: applicant_pii,
        trace_id: trace_id,
        dob_year_only: dob_year_only,
      }
    end

    it 'runs' do
      expect_any_instance_of(Aamva::Proofer).to receive(:proof).and_return(Proofer::Result.new)
      IdentityIdpFunctions::ProofResolution.handle(event: event, context: nil)
    end

    context 'when called with a block' do
      it 'gives the results to the block instead of posting to the callback URL' do
        expect_any_instance_of(Aamva::Proofer).to receive(:proof).and_return(Proofer::Result.new)
        yielded_result = nil
        IdentityIdpFunctions::ProofResolution.handle(
          event: event,
          context: nil,
        ) do |result|
          yielded_result = result
        end

        expect(yielded_result).to eq(
          resolution_result: {
            exception: nil,
            errors: {},
            messages: [],
            success: true,
            timed_out: false,
            context: { stages: [
              { resolution: LexisNexis::InstantVerify::Proofer.vendor_name },
              { state_id: Aamva::Proofer.vendor_name },
            ] },
            transaction_id: nil,
          },
        )

        expect(a_request(:post, callback_url)).to_not have_been_made
      end
    end

    context 'dob_year_only, failed response from lexisnexis' do
      let(:dob_year_only) { true }
      let(:lexisnexis_response) do
        {
          'Status' => {
            'CoversationId' => SecureRandom.hex,
            'Workflow' => 'foobar.baz',
            'TransactionStatus' => 'error',
            'TransactionReasonCode' => {
              'Code' => 'invalid_transaction_initiate',
            },
          },
          'Information' => {
            'InformationType' => 'error-details',
            'Code' => 'invalid_transaction_initiate',
            'Description' => 'Error: Invalid Transaction Initiate',
            'DetailDescription' => [
              { 'Text' => 'Date of Birth is not a valid date' }
            ]
          },
        }
      end

    let(:expected_callback_response) do
      {
        resolution_result: {
          exception: kind_of(String),
          errors: {},
          messages: [],
          success: false,
          timed_out: false,
          context: { stages: [
            { state_id: Aamva::Proofer.vendor_name },
            { resolution: LexisNexis::InstantVerify::Proofer.vendor_name },
          ] },
          transaction_id: nil,
        },
      }
    end

      it 'has a failed repsonse' do
        expect_any_instance_of(Aamva::Proofer).to receive(:proof).and_return(Proofer::Result.new)
        IdentityIdpFunctions::ProofResolution.handle(event: event, context: nil)
      end
    end
  end

  describe '#proof' do
    let(:should_proof_state_id) { true }
    let(:lexisnexis_proofer) { instance_double(LexisNexis::InstantVerify::Proofer) }
    let(:aamva_proofer) { instance_double(Aamva::Proofer) }
    let(:dob_year_only) { false }

    subject(:function) do
      IdentityIdpFunctions::ProofResolution.new(
        callback_url: callback_url,
        applicant_pii: applicant_pii,
        should_proof_state_id: should_proof_state_id,
        trace_id: trace_id,
        dob_year_only: dob_year_only,
      )
    end

    before do
      allow(function).to receive(:lexisnexis_proofer).and_return(lexisnexis_proofer)
      allow(function).to receive(:aamva_proofer).and_return(aamva_proofer)

      stub_request(:post, callback_url).
        with(headers: { 'X-API-AUTH-TOKEN' => idp_api_auth_token })
    end

    context 'with a successful response from the proofer' do
      before do
        expect(lexisnexis_proofer).to receive(:proof).
          and_return(Proofer::Result.new)

        expect(aamva_proofer).to receive(:proof).
          and_return(Proofer::Result.new)
      end

      it 'posts back to the callback url' do
        function.proof

        expect(WebMock).to have_requested(:post, callback_url)
      end

      it_behaves_like 'callback url behavior'

      it 'logs the trace_id and timing info' do
        expect(function).to receive(:log_event).with(hash_including(:timing, trace_id: trace_id))

        function.proof
      end
    end

    context 'does not call state id with an unsuccessful response from the proofer' do
      it 'posts back to the callback url' do
        expect(lexisnexis_proofer).to receive(:proof).
          and_return(Proofer::Result.new(exception: 'error'))
        expect(aamva_proofer).not_to receive(:proof)

        function.proof

        expect(WebMock).to have_requested(:post, callback_url)
      end
    end

    context 'with a connection error talking to the proofer' do
      before do
        allow(LexisNexis::InstantVerify::Proofer).to receive(:proof).
          and_raise(Faraday::ConnectionFailed.new('error')).
          and_raise(Faraday::ConnectionFailed.new('error')).
          and_raise(Faraday::ConnectionFailed.new('error'))
      end

      it 'retries 3 times then errors' do
        expect(WebMock).to_not have_requested(:post, callback_url)
      end
    end

    context 'no state_id proof' do
      let(:should_proof_state_id) { false }

      it 'does not call state_id proof if resolution proof is successful' do
        expect(lexisnexis_proofer).to receive(:proof).
          and_return(Proofer::Result.new)

        expect(aamva_proofer).not_to receive(:proof)
        function.proof

        expect(WebMock).to have_requested(:post, callback_url)
      end
    end

    context 'checking DOB year only' do
      let(:dob_year_only) { true }

      it 'only sends the birth year to LexisNexis (extra applicant attribute)' do
        expect(aamva_proofer).to receive(:proof).and_return(Proofer::Result.new)
        expect(lexisnexis_proofer).to receive(:proof).
          with(hash_including(dob_year_only: true)).
          and_return(Proofer::Result.new)

        function.proof
      end

      it 'does not check LexisNexis when AAMVA proofing does not match' do
        expect(aamva_proofer).to receive(:proof).and_return(Proofer::Result.new(exception: 'error'))
        expect(lexisnexis_proofer).to_not receive(:proof)

        function.proof
      end

      it 'logs the correct context' do
        transaction_id = SecureRandom.uuid

        expect(aamva_proofer).to receive(:proof).and_return(Proofer::Result.new)
        expect(lexisnexis_proofer).to receive(:proof).
          and_return(Proofer::Result.new(transaction_id: transaction_id))

        function.proof

        expect(WebMock).to(have_requested(:post, callback_url).with do |request|
          body = JSON.parse(request.body, symbolize_names: true)

          expect(body.dig(:resolution_result, :context, :stages)).to eq [
            { state_id: 'aamva:state_id' },
            { resolution: 'lexisnexis:instant_verify' },
          ]

          expect(body.dig(:resolution_result, :transaction_id)).to eq(transaction_id)
        end)
      end
    end

    context 'when IDP auth token is blank' do
      it_behaves_like 'misconfigured proofer'
    end

    context 'when there are no params in the ENV' do
      before do
        ENV.clear
      end

      it 'loads secrets from SSM and puts them in the ENV' do
        expect(function.ssm_helper).to receive(:load).
          with('resolution_proof_result_token').and_return(idp_api_auth_token)
        expect(function.ssm_helper).to receive(:load).
          with('lexisnexis_account_id').and_return('aaa')
        expect(function.ssm_helper).to receive(:load).
          with('lexisnexis_request_mode').and_return('aaa')
        expect(function.ssm_helper).to receive(:load).
          with('lexisnexis_username').and_return('aaa')
        expect(function.ssm_helper).to receive(:load).
          with('lexisnexis_password').and_return('aaa')
        expect(function.ssm_helper).to receive(:load).
          with('lexisnexis_base_url').and_return('aaa')
        expect(function.ssm_helper).to receive(:load).
          with('lexisnexis_instant_verify_workflow').and_return('aaa')
        expect(function.ssm_helper).to receive(:load).
          with('aamva_public_key').and_return('aaa')
        expect(function.ssm_helper).to receive(:load).
          with('aamva_private_key').and_return('aaa')

        expect(lexisnexis_proofer).to receive(:proof).
          and_return(Proofer::Result.new)

        expect(aamva_proofer).to receive(:proof).
          and_return(Proofer::Result.new)

        function.proof

        expect(WebMock).to have_requested(:post, callback_url)

        expect(ENV).to include(
          'lexisnexis_account_id' => 'aaa',
          'lexisnexis_request_mode' => 'aaa',
          'lexisnexis_username' => 'aaa',
          'lexisnexis_password' => 'aaa',
          'lexisnexis_base_url' => 'aaa',
          'lexisnexis_instant_verify_workflow' => 'aaa',
          'aamva_public_key' => 'aaa',
          'aamva_private_key' => 'aaa',
        )
      end
    end
  end
end
