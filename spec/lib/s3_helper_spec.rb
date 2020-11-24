require 'spec_helper'
require 'securerandom'

RSpec.describe IdentityIdpFunctions::S3Helper do
  subject(:s3_helper) { IdentityIdpFunctions::S3Helper.new }

  describe '#download' do
    let(:url) do
      "https://#{bucket_name}.amazonaws.com/#{prefix}?signed=true&param=true&signature=123"
    end
    let(:bucket_name) { 'bucket123456' }
    let(:prefix) { SecureRandom.uuid }
    let(:body) { SecureRandom.random_bytes(128) }

    it 'downloads by extracing prefix and bucket from s3 URLs' do
      Aws.config[:s3] = {
        stub_responses: {
          get_object: lambda do |context|
            expect(context.params[:key]).to eq(prefix)
            expect(context.params[:bucket]).to eq(bucket_name)

            { body: body }
          end,
        },
      }

      expect(s3_helper.download(url)).to eq(body)
    end

    it 'returns binary-encoded string bodies' do
      Aws.config[:s3] = {
        stub_responses: {
          get_object: {
            body: body,
          },
        },
      }

      expect(s3_helper.download(url).encoding.name).to eq('ASCII-8BIT')
    end
  end
end
