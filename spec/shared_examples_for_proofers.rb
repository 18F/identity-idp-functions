require 'spec_helper'

RSpec.shared_examples 'misconfigured proofer' do
  before do
    ENV['IDP_API_AUTH_TOKEN'] = nil
  end

  it 'raises error if auth token is not configured and block is not given' do
    expect { function.proof }.to raise_exception 'IDP_API_AUTH_TOKEN is not configured'

    expect(WebMock).to_not have_requested(:post, callback_url)
  end
end

RSpec.shared_examples 'callback url behavior' do
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

  context 'with a non-200 response posting to the callback url' do
    before do
      stub_request(:post, callback_url).
        to_return(status: 401)
    end

    it 'errors immediately' do
      expect { function.proof }.to raise_error(Faraday::UnauthorizedError)

      expect(a_request(:post, callback_url)).to have_been_made.once
    end
  end
end
