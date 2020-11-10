require 'securerandom'
require 'identity-idp-functions/proof_document_mock'

RSpec.describe IdentityIdpFunctions::ProofDocumentMock do
  let(:idp_api_auth_token) { SecureRandom.hex }
  let(:callback_url) { 'https://example.login.gov/api/callbacks/proof-document/:token' }
  let(:applicant_pii) do
    {
      first_name: 'Johnny',
      last_name: 'Appleseed',
      uuid: SecureRandom.hex,
      dob: '01/01/1970',
      ssn: '123456789',
      phone: '18888675309',
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
              document_result: {
                exception: nil,
                errors: {},
                messages: [],
                success: true,
                timed_out: false,
                context: { stages: [
                  { document: 'DocumentMock' },
                ] },
              },
            )
      end
    end

    let(:event) do
      {
        callback_url: callback_url,
        encryption_key: '12345678901234567890123456789012',
        front_image_iv: '1234567890123456',
        back_image_iv: '1234567890123456',
        selfie_image_iv: '1234567890123456',
        front_image_url: 'http://foo.com/bar1',
        back_image_url: 'http://foo.com/bar2',
        selfie_image_url: 'http://foo.com/bar3',
        liveness_checking_enabled: true,
      }
    end

    xit 'runs' do
      IdentityIdpFunctions::ProofDocumentMock.handle(event: event, context: nil)
    end

    xcontext 'when called with a block' do
      it 'gives the results to the block instead of posting to the callback URL' do
        yielded_result = nil
        IdentityIdpFunctions::ProofDocumentMock.handle(
          event: event,
          context: nil,
        ) do |result|
          yielded_result = result
        end

        expect(yielded_result).to eq(
          document_result: {
            exception: nil,
            errors: {},
            messages: [],
            success: true,
            timed_out: false,
            context: { stages: [
              { document: 'DocumentMock' },
            ] },
          },
        )

        expect(a_request(:post, callback_url)).to_not have_been_made
      end
    end
  end

  describe '#proof' do
    subject(:function) do
      IdentityIdpFunctions::ProofDocumentMock.new(
        callback_url: callback_url,
        encryption_key: '12345678901234567890123456789012',
        front_image_iv: '1234567890123456',
        back_image_iv: '1234567890123456',
        selfie_image_iv: '1234567890123456',
        front_image_url: 'http://foo.com/bar1',
        back_image_url: 'http://foo.com/bar2',
        selfie_image_url: 'http://foo.com/bar3',
        liveness_checking_enabled: true,
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

    context 'with an unsuccessful response from the proofer' do
      it 'posts back to the callback url' do
        function.proof

        expect(WebMock).to have_requested(:post, callback_url)
      end
    end

    context 'with a connection error talking to the proofer' do
      before do
        allow(IdentityIdpFunctions::DocumentMockClient).to receive(:proof).
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

    context 'when there are no params in the ENV' do
      before do
        ENV.clear
      end

      it 'loads secrets from SSM' do
        expect(function.ssm_helper).to receive(:load).with('document_proof_result_token').
          and_return(idp_api_auth_token)

        function.proof

        expect(WebMock).to have_requested(:post, callback_url)
      end
    end
  end
end
