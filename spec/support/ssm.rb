def stub_ssm(key_values)
  Aws.config[:ssm] = {
    stub_responses: {
      get_parameter: lambda do |context|
        # example: '/int/idp/doc-capture/aaa'
        key = context.params[:name].split('/').last

        { parameter: { value: key_values.fetch(key) } }
      end,
    },
  }
end
