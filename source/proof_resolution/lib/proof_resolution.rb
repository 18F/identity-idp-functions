require 'proofer'
require 'lexisnexis'
require 'aamva'

module IdentityIdpFunctions
  class ProofResolution
    def self.handle(event:, context:)
      # TODO: actually call
      LexisNexis::InstantVerify::Proofer.new
      Aamva::Proofer.new
    end
  end
end
