require 'identity-idp-functions/version'

# This is the entry point for this repository as a gem, ex
# require 'identity-idp-functions'

module IdentityIdpFunctions
  module_function

  class MisconfiguredLambdaError < StandardError
    def message
      'IDP_API_AUTH_TOKEN is not configured'
    end
  end

  # Helper for building a ruby require path for
  # "source/$function_name/lib/$function_name.rb"
  def function_path(function_name)
    File.expand_path(File.join(root_path, 'source', function_name, 'lib', "#{function_name}.rb"))
  end

  def helper_path(helper_name)
    File.expand_path(File.join(root_path, 'source', 'aws-ruby-sdk', "#{helper_name}.rb"))
  end

  def root_path
    File.expand_path(File.join(__dir__, '..'))
  end
end

require IdentityIdpFunctions.helper_path('ssm_helper')
require IdentityIdpFunctions.helper_path('faraday_helper')
