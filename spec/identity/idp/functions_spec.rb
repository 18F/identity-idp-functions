RSpec.describe Identity::Idp::Functions do
  it "has a version number" do
    expect(Identity::Idp::Functions::VERSION).not_to be nil
  end

  it "loads the handlers functions" do
    expect(defined? Identity::Idp::Functions::DemoFunction::Handler).to be_truthy
  end
end
