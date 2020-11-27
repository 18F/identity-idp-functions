require 'openssl'

module IdentityIdpFunctions
  class EncryptionHelper
    def decrypt(data:, iv:, key:)
      cipher = OpenSSL::Cipher.new('aes-256-gcm')
      cipher.decrypt
      cipher.iv = iv
      cipher.key = key
      cipher.auth_data = ''
      cipher.auth_tag = data[-16..-1]

      cipher.update(data[0..-17]) + cipher.final
    end

    def encrypt(data:, iv:, key:)
      cipher = OpenSSL::Cipher.new('aes-256-gcm')
      cipher.encrypt
      cipher.iv = iv
      cipher.key = key
      cipher.auth_data = ''

      encrypted = cipher.update(data) + cipher.final
      tag = cipher.auth_tag # produces 16 bytes tag by default

      encrypted + tag
    end
  end
end
