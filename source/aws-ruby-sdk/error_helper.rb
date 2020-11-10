module IdentityIdpFunctions
  class MisconfiguredLambdaError < StandardError
    def message
      'IDP_API_AUTH_TOKEN is not configured'
    end
  end
end
