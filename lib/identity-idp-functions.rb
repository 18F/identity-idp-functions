require 'identity-idp-functions/version'

# This is the entry point for this repository as a gem, ex
# require 'identity-idp-functions'

# Load each lambda, they should have a file at "source/$function_name/lib/$function_name.rb"
root = File.expand_path(File.join(__dir__, '..'))
Dir[File.join(root, 'source', '*', 'lib')].each do |lambda_lib_dir|
  lambda_name = File.basename(lambda_lib_dir.gsub(%r|lib/?$|, ''))
  require File.expand_path(File.join(lambda_lib_dir, "#{lambda_name}.rb"))
end

module IdentityIdpFunctions
end
