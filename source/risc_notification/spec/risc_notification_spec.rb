require 'identity-idp-functions/risc_notification'

RSpec.describe IdentityIdpFunctions::RiscNotification do
  let(:push_notification_url) { 'https://example.com/risc/notify' }
  let(:jwt) { SecureRandom.hex } # opaque payload stands in for a real JWT

  describe '.handle' do
    let(:event) do
      {
        push_notification_url: push_notification_url,
        jwt: jwt,
      }
    end

    it 'posts to the push_notification_url with the right headers' do
      req = stub_request(:post, push_notification_url).with(
              headers: {
                'Accept' => 'application/json',
                'Content-Type' => 'application/secevent+jwt',
              },
              body: jwt
            )

      IdentityIdpFunctions::RiscNotification.handle(event: event, context: nil)

      expect(req).to have_been_requested
    end
  end

  describe '#notify' do
    subject(:function) do
      IdentityIdpFunctions::RiscNotification.new(
        push_notification_url: push_notification_url,
        jwt: jwt,
      )
    end

    it 'logs timing info and the response code' do
      stub_request(:post, push_notification_url).to_return(status: 201)

      expect(function).to receive(:log_event).with(hash_including(
        name: 'RiscNotification',
        response_code: 201,
        timing: {
          'deliver_notification' => kind_of(Float),
        }
      ))

      function.notify
    end

    context 'with a timeout from the endpoint' do
      before do
        stub_request(:post, push_notification_url).to_timeout
      end

      it 'raises and does not retry' do
        expect { function.notify }.to raise_error(Faraday::ConnectionFailed)

        expect(a_request(:post, push_notification_url)).to have_been_requested.once
      end

      it 'still logs timing info' do
        expect(function).to receive(:log_event).with(
          hash_including(name: 'RiscNotification')
        )

        expect { function.notify }.to raise_error(Faraday::ConnectionFailed)
      end
    end

    context 'with a 400 from the endpoint' do
      before do
        stub_request(:post, push_notification_url).to_return(status: 400)
      end

      it 'raises and does not retry' do
        expect { function.notify }.to raise_error(Faraday::BadRequestError)

        expect(a_request(:post, push_notification_url)).to have_been_requested.once
      end

      it 'still logs timing info' do
        expect(function).to receive(:log_event).with(
          hash_including(name: 'RiscNotification')
        )

        expect { function.notify }.to raise_error(Faraday::BadRequestError)
      end
    end
  end
end

