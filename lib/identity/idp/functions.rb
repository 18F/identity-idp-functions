require 'identity/idp/functions/version'

# This is the entry point for this repository as a gem, ex
# require 'identity/idp/functions'

# Load each lambda's handler.rb
root = File.expand_path(File.join(__dir__, '..', '..', '..'))
Dir[File.join(root, 'source', '*', 'src', 'handler.rb')].each do |lambda_src_dir|
  require lambda_src_dir
end

module Identity
  module Idp
    module Functions
    end
  end
end
