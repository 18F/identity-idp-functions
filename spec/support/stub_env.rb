def stub_env(example, key_values)
  old_env = {}

  key_values.each do |key, new_value|
    old_env[key] = ENV[key]
    ENV[key] = new_value
  end

  example.run

  old_env.each do |key, old_value|
    ENV[key] = old_value
  end
end
