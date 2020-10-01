RSpec.describe IdentityIdpFunctions::DemoFunction do
  around do |example|
    stub_env(
      example,
      'S3_BUCKET_NAME' => 'test-bucket',
      'AWS_REGION' => 'test-region',
    )
  end

  before do
    Aws.config[:s3] = {
      stub_responses: {
        list_objects_v2: {
          contents: [
            { key: 'my-item' },
          ],
        },
      },
    }
  end

  let(:event) { { "body" => "" } }
  let(:logger) { instance_double(Logger) }

  it 'logs items in a bucket' do
    expect(logger).to receive(:info).with(event)
    expect(logger).to receive(:info).with('my-item')

    IdentityIdpFunctions::DemoFunction.handle(event: event, context: nil, logger: logger)
  end
end
