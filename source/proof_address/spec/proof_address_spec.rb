require 'securerandom'

RSpec.describe IdentityIdpFunctions::ProofAddress do
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
    around do |example|
      stub_env(
        example,
        'lexisnexis_account_id' => 'abc123',
        'lexisnexis_request_mode' => 'aaa',
        'lexisnexis_username' => 'aaa',
        'lexisnexis_password' => 'aaa',
        'lexisnexis_base_url' => 'https://lexisnexis.example.com/',
        'lexisnexis_phone_finder_workflow' => 'aaa',
      )
    end

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
        with(headers: { 'Content-Type' => 'application/json' }) do |request|
          expect(JSON.parse(request.body, symbolize_names: true)).to eq(
            address_idv_result: {
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
      )
    end
  end
end
