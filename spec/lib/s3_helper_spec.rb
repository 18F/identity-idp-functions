require 'spec_helper'
require 'securerandom'

RSpec.describe IdentityIdpFunctions::S3Helper do
  subject(:s3_helper) { IdentityIdpFunctions::S3Helper.new }

  describe '#download' do
    let(:bucket_name) { 'bucket123456' }
    let(:prefix) { SecureRandom.uuid }
    let(:body) { SecureRandom.random_bytes(128) }

    before do
      Aws.config[:s3] = {
        stub_responses: {
          get_object: lambda do |context|
            expect(context.params[:key]).to eq(prefix)
            expect(context.params[:bucket]).to eq(bucket_name)

            { body: body }
          end,
        },
      }
    end

    context 'with subdomain bucket format' do
      let(:url) do
        "https://s3.region-name.amazonaws.com/#{bucket_name}/#{prefix}?param=true&signature=123"
      end

      it 'downloads by extracing prefix and bucket from s3 URLs' do
        expect(s3_helper.download(url)).to eq(body)
      end
    end

    context 'with path bucket format' do
      let(:url) do
        "https://#{bucket_name}.s3.region-name.amazonaws.com/#{prefix}?param=true&signature=123"
      end

      it 'downloads by extracing prefix and bucket from s3 URLs' do
        expect(s3_helper.download(url)).to eq(body)
      end
    end

    let(:url) do
      "https://s3.region-name.amazonaws.com/#{bucket_name}/#{prefix}?param=true&signature=123"
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
