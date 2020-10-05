require 'identity-idp-functions/version'

# This is the entry point for this repository as a gem, ex
# require 'identity-idp-functions'

module IdentityIdpFunctions
  module_function

  # Helper for building a ruby require path for
  # "source/$function_name/lib/$function_name.rb"
  def function_path(function_name)
    root = File.expand_path(File.join(__dir__, '..'))
    File.expand_path(File.join(root, 'source', function_name, 'lib', "#{function_name}.rb"))
  end
end
