require 'spec_helper'

RSpec.shared_examples 'misconfigured proofer' do
  it 'raises error if auth token is not configured and block is not given' do
    expect { function.proof }.to raise_exception 'IDP_API_AUTH_TOKEN is not configured'

    expect(WebMock).to_not have_requested(:post, callback_url)
  end
end
