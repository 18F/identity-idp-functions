require 'securerandom'

RSpec.describe IdentityIdpFunctions::ProofAddress do
  let(:idp_api_auth_token) { SecureRandom.hex }
  let(:callback_url) { 'https://example.login.gov/api/callbacks/proof-address/:token' }
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
        'lexisnexis_account_id' => 'abc123',
        'lexisnexis_request_mode' => 'aaa',
        'lexisnexis_username' => 'aaa',
        'lexisnexis_password' => 'aaa',
        'lexisnexis_base_url' => 'https://lexisnexis.example.com/',
        'lexisnexis_phone_finder_workflow' => 'aaa',
      )

      stub_request(
        :post,
        'https://lexisnexis.example.com/restws/identity/v2/abc123/aaa/conversation'
      ).to_return(
        body: {
          "Status" => {
            "TransactionStatus" => "passed"
          }
        }.to_json
      )

      stub_request(:post, callback_url).
        with(
          headers: {
            'Content-Type' => 'application/json',
            'X-API-AUTH-TOKEN' => idp_api_auth_token,
          },
        ) do |request|
          expect(JSON.parse(request.body, symbolize_names: true)).to eq(
            address_result: {
              exception: nil,
              errors: {},
              messages: [],
              success: true,
            }
          )
        end
    end

    let(:body) do
      {
        callback_url: callback_url,
        applicant_pii: applicant_pii,
      }
    end

    it 'runs' do
      IdentityIdpFunctions::ProofAddress.handle(event: { 'body' => body.to_json }, context: nil)
    end
  end

  describe '#proof' do
    subject(:function) do
      IdentityIdpFunctions::ProofAddress.new(
        callback_url: callback_url,
        applicant_pii: applicant_pii,
        idp_api_auth_token: idp_api_auth_token,
      )
    end

    let(:lexisnexis_proofer) { instance_double(LexisNexis::PhoneFinder::Proofer) }

    before do
      allow(function).to receive(:lexisnexis_proofer).and_return(lexisnexis_proofer)

      stub_request(:post, callback_url).
        with(headers: { 'X-API-AUTH-TOKEN' => idp_api_auth_token })
    end

    context 'with a successful response from the proofer' do
      before do
        expect(lexisnexis_proofer).to receive(:proof).
          and_return(Proofer::Result.new)
      end

      it 'posts back to the callback url' do
        function.proof

        expect(WebMock).to have_requested(:post, callback_url)
      end
    end

    context 'with an unsuccessful response from the proofer' do
      before do
        expect(lexisnexis_proofer).to receive(:proof).
          and_return(Proofer::Result.new(exception: RuntimeError.new))
      end

      it 'posts back to the callback url' do
        function.proof

        expect(WebMock).to have_requested(:post, callback_url)
      end
    end

    context 'with a connection error talking to the proofer' do
      before do
        allow(lexisnexis_proofer).to receive(:proof).
          and_raise(Faraday::ConnectionFailed.new('error')).
          and_raise(Faraday::ConnectionFailed.new('error')).
          and_raise(Faraday::ConnectionFailed.new('error'))
      end

      it 'retries 3 times then errors' do
        expect { function.proof }.to raise_error(Faraday::ConnectionFailed)

        expect(WebMock).to_not have_requested(:post, callback_url)
      end
    end

    context 'with a connection error posting to the callback url' do
      before do
        expect(lexisnexis_proofer).to receive(:proof).
          and_return(Proofer::Result.new)

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
  end
end
