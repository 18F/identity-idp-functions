require 'spec_helper'
load File.join(IdentityIdpFunctions.root_path, 'bin/generate-template')

RSpec.describe 'source/template.yaml' do
  it 'matches the generated source' do
    actual = File.read(File.join(IdentityIdpFunctions.root_path, 'source/template.yaml'))
    expected = StringIO.new.tap do |io|
      IdentityIdpFunctions::GenerateTemplate.new(out: io).run
    end.string

    expect(actual).to eq(expected)
  end
end
