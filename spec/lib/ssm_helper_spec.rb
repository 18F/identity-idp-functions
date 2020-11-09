require 'spec_helper'

RSpec.describe IdentityIdpFunctions::SsmHelper do
  before do
    stub_const('ENV', 'ENVIRONMENT_NAME' => 'int')
  end

  subject(:helper) { IdentityIdpFunctions::SsmHelper.new }

  describe '#load' do
    it 'loads a secret from AWS' do
      Aws.config[:ssm] = {
        stub_responses: {
          get_parameter: lambda do |context|
            expect(context.params[:name]).to eq('/int/idp/doc-capture/aaa')
            expect(context.params[:with_decryption]).to eq(true)

            { parameter: { value: 'bbb' } }
          end,
        },
      }

      expect(helper.load('aaa')).to eq('bbb')
    end
  end
end
