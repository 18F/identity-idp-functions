def encrypt_and_stub_s3(body:, url:, iv:, key:)
  prefix = URI(url).path.gsub(%r{^/}, '')

  @responses ||= {}
  @responses[prefix] = IdentityIdpFunctions::EncryptionHelper.new.encrypt(
    data: body, iv: iv, key: key,
  )

  Aws.config[:s3] = {
    stub_responses: {
      get_object: lambda do |context|
        { body: @responses.fetch(context.params[:key]) }
      end,
    },
  }
end
