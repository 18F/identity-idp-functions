require 'securerandom'
require 'identity-idp-functions/proof_document'
require 'identity_doc_auth'

RSpec.describe IdentityIdpFunctions::ProofDocument do
  let(:idp_api_auth_token) { SecureRandom.hex }
  let(:callback_url) { 'https://example.login.gov/api/callbacks/proof-document/:token' }
  let(:event) do
    {
      encryption_key: '12345678901234567890123456789012',
      front_image_iv: '1234567890123456',
      back_image_iv: '1234567890123456',
      selfie_image_iv: '1234567890123456',
      front_image_url: 'http://foo.com/bar1',
      back_image_url: 'http://foo.com/bar2',
      selfie_image_url: 'http://foo.com/bar3',
      liveness_checking_enabled: true,
      callback_url: callback_url,
    }
  end
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

  before do
    stub_const(
      'ENV',
      'IDP_API_AUTH_TOKEN' => idp_api_auth_token,
      'acuant_assure_id_password' => 'aaa',
      'acuant_assure_id_subscription_id' => 'aaa',
      'acuant_assure_id_url' => 'https://example.com',
      'acuant_assure_id_username' => 'aaa',
      'acuant_facial_match_url' => 'https://facial_match.example.com',
      'acuant_passlive_url' => 'https://liveness.example.com',
      'acuant_timeout' => 60,
    )

    stub_request(:get, 'http://169.254.169.254/2016-09-02/dynamic/instance-identity/document').
        to_return(body: {
            'region' => 'us-west-1',
            'accountId' => '12345',
        }.to_json)

    url = URI.join('https://example.com', '/AssureIDService/Document/Instance')
    stub_request(:post, url).to_return(body: '"this-is-a-test-instance-id"')
    stub_request(:post, "https://example.com/AssureIDService/Document/this-is-a-test-instance-id/Image?light=0&side=0").to_return(body: '')
    stub_request(:post, "https://example.com/AssureIDService/Document/this-is-a-test-instance-id/Image?light=0&side=1").to_return(body: '')
    stub_request(:get, "https://example.com/AssureIDService/Document/this-is-a-test-instance-id").to_return(body: '{"Result":1}')
    stub_request(:get, "https://example.com/AssureIDService/Document/this-is-a-test-instance-id/Field/Image?key=Photo").to_return(body: '')
    stub_request(:post, "https://facial_match.example.com/api/v1/facematch").to_return(body:'{"IsMatch":true}')
    stub_request(:post, "https://liveness.example.com/api/v1/liveness").to_return(body:'{"LivenessResult":{"LivenessAssessment": "Live"}}')

    allow_any_instance_of(OpenSSL::Cipher::AES).to receive(:update).and_return('foo')
    allow_any_instance_of(OpenSSL::Cipher::AES).to receive(:final).and_return('bar')
    allow_any_instance_of(IdentityDocAuth::Acuant::Responses::GetResultsResponse).to receive(:pii_from_doc).and_return(applicant_pii)
  end

  describe '.handle' do
    before do
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
            document_result: {
              acuant_error:{ code:nil, message: nil}, billed: true, errors:{},
              liveness_score: nil,
              match_score: nil,
              raw_alerts: [],
              result: 'Passed',
              success: true,
            }
          )
        end
    end

    it 'runs' do
      IdentityIdpFunctions::ProofDocument.handle(event: event, context: nil)
    end

    context 'when called with a block' do
      it 'gives the results to the block instead of posting to the callback URL' do
        yielded_result = nil
        IdentityIdpFunctions::ProofDocument.handle(
          event: event,
          context: nil
        ) do |result|
          yielded_result = result
        end

        expect(yielded_result).to eq(
          document_result: {
            acuant_error:{ code:nil, message: nil}, billed: true, errors:{},
            liveness_score: nil,
            match_score: nil,
            raw_alerts: [],
            result: 'Passed',
            success: true,
          }
        )

        expect(a_request(:post, callback_url)).to_not have_been_made
      end
    end
  end

  describe '#proof' do
    subject(:function) do
      IdentityIdpFunctions::ProofDocument.new(event)
    end

    let(:document_proofer) { instance_double(IdentityDocAuth::Acuant::AcuantClient) }

    before do
      allow(function).to receive(:document_proofer).and_return(document_proofer)

      stub_request(:post, callback_url).
        with(headers: { 'X-API-AUTH-TOKEN' => idp_api_auth_token })
    end

    context 'with a successful response from the proofer' do
      before do
        expect(document_proofer).to receive(:post_images).
          and_return(Proofer::Result.new)
      end

      it 'posts back to the callback url' do
        function.proof

        expect(WebMock).to have_requested(:post, callback_url)
      end
    end

    context 'with an unsuccessful response from the proofer' do
      before do
        expect(document_proofer).to receive(:post_images).
          and_return(Proofer::Result.new(exception: RuntimeError.new))
      end

      it 'posts back to the callback url' do
        function.proof

        expect(WebMock).to have_requested(:post, callback_url)
      end
    end

    context 'with a connection error talking to the proofer' do
      before do
        allow(document_proofer).to receive(:post_images).
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
        expect(document_proofer).to receive(:post_images).
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

    context 'when there are no params in the ENV' do
      before do
        ENV.clear

        expect(document_proofer).to receive(:post_images).
          and_return(Proofer::Result.new)
      end

      it 'loads secrets from SSM and puts them in the ENV' do
        expect(function.ssm_helper).to receive(:load).with('document_proof_result_token').and_return(idp_api_auth_token)
        expect(function.ssm_helper).to receive(:load).with('acuant_assure_id_password').and_return('aaa')
        expect(function.ssm_helper).to receive(:load).with('acuant_assure_id_subscription_id').and_return('aaa')
        expect(function.ssm_helper).to receive(:load).with('acuant_assure_id_url').and_return('aaa')
        expect(function.ssm_helper).to receive(:load).with('acuant_assure_id_username').and_return('aaa')
        expect(function.ssm_helper).to receive(:load).with('acuant_facial_match_url').and_return('aaa')
        expect(function.ssm_helper).to receive(:load).with('acuant_passlive_url').and_return('aaa')

        function.proof

        expect(WebMock).to have_requested(:post, callback_url)

        expect(ENV).to include(
          'acuant_assure_id_password' => 'aaa',
          'acuant_assure_id_subscription_id' => 'aaa',
          'acuant_assure_id_url' => 'https://example.com',
          'acuant_assure_id_username' => 'aaa',
          'acuant_facial_match_url' => 'https://facial_match.example.com',
          'acuant_passlive_url' => 'https://liveness.example.com',
        )
      end
    end
  end
end