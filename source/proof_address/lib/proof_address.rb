require 'proofer'
require 'lexisnexis'

module IdentityIdpFunctions
  class ProofAddress
    def self.handle(event:, context:)
      LexisNexis::PhoneFinder::Proofer.new
    end
  end
end
