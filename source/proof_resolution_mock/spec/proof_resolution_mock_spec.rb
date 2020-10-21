require 'securerandom'
require 'identity-idp-functions/proof_resolution_mock'

RSpec.describe IdentityIdpFunctions::ProofResolutionMock do
  let(:idp_api_auth_token) { SecureRandom.hex }
  let(:callback_url) { 'https://example.login.gov/api/callbacks/proof-resolution/:token' }
  let(:ssn) { '123456789' }
  let(:bad_ssn) { IdentityIdpFunctions::ResolutionMockClient::NO_CONTACT_SSN }
  let(:applicant_pii) do
    {
      first_name: 'Johnny',
      last_name: 'Appleseed',
      uuid: SecureRandom.hex,
      dob: '01/01/1970',
      ssn: ssn,
      zipcode: '53206',
      phone: '18888675309',
      state_id_number: '123456',
      state_id_type: 'drivers_license',
      state_id_jurisdiction: 'WI',
    }
  end

  describe '.handle' do
    before do
      stub_const(
        'ENV',
        'IDP_API_AUTH_TOKEN' => idp_api_auth_token,
      )

      stub_request(:post, callback_url).
        with(
          headers: {
            'Content-Type' => 'application/json',
            'X-API-AUTH-TOKEN' => idp_api_auth_token,
          },
      ) do |request|
            expect(JSON.parse(request.body, symbolize_names: true)).to eq(
              resolution_result: {
                exception: nil,
                errors: {},
                messages: [],
                success: true,
                timed_out: false,
                context: { stages: [
                  { resolution: 'ResolutionMock' },
                  { state_id: 'StateIdMock' },
                ]}
              }
            )
          end
    end

    let(:body) do
      {
        callback_url: callback_url,
        should_proof_state_id: true,
        applicant_pii: applicant_pii,
      }
    end

    it 'runs' do
      IdentityIdpFunctions::ProofResolutionMock.handle(event: { 'body' => body.to_json }, context: nil)
    end

    context 'when called with a block' do
      it 'gives the results to the block instead of posting to the callback URL' do
        yielded_result = nil
        IdentityIdpFunctions::ProofResolutionMock.handle(
          event: { 'body' => body.to_json },
          context: nil
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
              { resolution: 'ResolutionMock' },
              { state_id: 'StateIdMock' },
            ]}
          }
        )

        expect(a_request(:post, callback_url)).to_not have_been_made
      end
    end
  end

  describe '#proof' do
    let(:should_proof_state_id) { true }

    subject(:function) do
      IdentityIdpFunctions::ProofResolutionMock.new(
        callback_url: callback_url,
        applicant_pii: applicant_pii,
        should_proof_state_id: should_proof_state_id,
      )
    end

    before do
      stub_request(:post, callback_url).
        with(headers: { 'X-API-AUTH-TOKEN' => idp_api_auth_token })

      stub_const(
        'ENV',
        'IDP_API_AUTH_TOKEN' => idp_api_auth_token,
      )
    end

    context 'with a successful response from the proofer' do
      it 'posts back to the callback url' do
        function.proof

        expect(WebMock).to have_requested(:post, callback_url)
      end
    end

    context 'does not call state id with an unsuccessful response from the proofer' do
      let(:ssn) { bad_ssn }
      it 'posts back to the callback url' do
        function.proof
        expect_any_instance_of(IdentityIdpFunctions::StateIdMockClient).not_to receive(:proof)

        expect(WebMock).to have_requested(:post, callback_url)
      end
    end

    context 'with a connection error talking to the proofer' do
      before do
        allow(IdentityIdpFunctions::ProofResolutionMock).to receive(:proof).
          and_raise(Faraday::ConnectionFailed.new('error')).
          and_raise(Faraday::ConnectionFailed.new('error')).
          and_raise(Faraday::ConnectionFailed.new('error'))
      end

      it 'retries 3 times then errors' do
        expect(WebMock).to_not have_requested(:post, callback_url)
      end
    end

    context 'with a connection error posting to the callback url' do
      before do
        stub_request(:post, callback_url).
          to_timeout.
          to_timeout.
          to_timeout
      end

      it 'retries 3 then errors' do
        expect { function.proof }.to raise_error(Faraday::ConnectionFailed)

        expect(a_request(:post, callback_url)).to have_been_made.times(3)
      end
    end

    context 'no state_id proof' do
      let(:should_proof_state_id) { false }

      it 'does not call state_id proof if resolution proof is successful' do
        expect_any_instance_of(IdentityIdpFunctions::StateIdMockClient).not_to receive(:proof)
        function.proof

        expect(WebMock).to have_requested(:post, callback_url)
      end
    end
  end
end
