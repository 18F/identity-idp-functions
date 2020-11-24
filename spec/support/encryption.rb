def encrypt_and_stub_s3(body:, url:, iv:, key:)
  prefix = URI(url).path.gsub(%r{^/}, '')

  @responses ||= {}
  @responses[prefix] = encrypt(data: body, iv: iv, key: key)

  Aws.config[:s3] = {
    stub_responses: {
      get_object: lambda do |context|
        { body: @responses.fetch(context.params[:key]) }
      end,
    },
  }
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
