RSpec.describe IdentityIdpFunctions do
  it "has a version number" do
    expect(IdentityIdpFunctions::VERSION).not_to be nil
  end

  it "loads the handlers functions" do
    require 'identity-idp-functions/demo_function'
    expect(defined? IdentityIdpFunctions::DemoFunction).to be_truthy
  end
end
