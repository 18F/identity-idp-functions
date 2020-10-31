require 'proofer'

module IdentityIdpFunctions
  class DocumentMockClient < Proofer::Base
    vendor_name 'DocumentMock'

    required_attributes :encryption_key, :front_image_iv, :back_image_iv, :selfie_image_iv
    required_attributes :front_image_url, :back_image_url, :selfie_image_url
    required_attributes :liveness_checking_enabled

    stage :document

    UNVERIFIABLE_PHONE_NUMBER = '7035555555'
    PROOFER_TIMEOUT_PHONE_NUMBER = '7035555888'
    FAILED_TO_CONTACT_PHONE_NUMBER = '7035555999'

    proof do |applicant, result|
      plain_phone = applicant[:phone].gsub(/\D/, '').gsub(/\A1/, '')
      if plain_phone == UNVERIFIABLE_PHONE_NUMBER
        result.add_error(:phone, 'The phone number could not be verified.')
      elsif plain_phone == FAILED_TO_CONTACT_PHONE_NUMBER
        raise 'Failed to contact proofing vendor'
      elsif plain_phone == PROOFER_TIMEOUT_PHONE_NUMBER
        raise Proofer::TimeoutError, 'document mock timeout'
      end
      result.context[:message] = 'some context for the mock document proofer'
    end
  end
end
