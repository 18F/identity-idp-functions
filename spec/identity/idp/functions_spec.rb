RSpec.describe IdentityIdpFunctions do
  it "has a version number" do
    expect(IdentityIdpFunctions::VERSION).not_to be nil
  end

  it "loads the handlers functions" do
    expect(defined? IdentityIdpFunctions::DemoFunction).to be_truthy
  end
end
