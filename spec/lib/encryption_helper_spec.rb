require 'spec_helper'
require 'securerandom'

RSpec.describe IdentityIdpFunctions::EncryptionHelper do
  subject(:encryption_helper) { IdentityIdpFunctions::EncryptionHelper.new }

  describe '#decrypt' do
    let(:key) { SecureRandom.random_bytes(32) }
    let(:iv) { SecureRandom.random_bytes(12) }
    let(:plaintext) { 'the quick brown fox jumps over the lazy dog' }

    it 'decrypts data' do
      encrypted = encryption_helper.encrypt(data: plaintext, iv: iv, key: key)

      expect(encryption_helper.decrypt(data: encrypted, iv: iv, key: key)).to eq(plaintext)
    end
  end
end
