# identity-idp-functions
IDP Lambda Functions for login.gov

## Usage

As a gem:

```ruby
gem 'identity-idp-functions', github: '18f/identity-idp-functions'
```

**The functions depend on various Github gem dependencies so they are lazily loaded**

Calling a handler directly:

```ruby
require 'identity-idp-functions/demo_function'

IdentityIdpFunctions::DemoFunction.handle(
  event: event,
  context: context
)
```

Expected local development workflow is with a block:

```ruby
require 'identity-idp-functions/proof_address'

IdentityIdpFunctions::ProofAddress.handle(event: event, context: context) do |result|
  store(result[:address_result])
end
```

## Adding a new Lambda

1. Lambdas should have an entry point at:
    ```
    source/$function_name/lib/$function_name.rb
    ```
2. Add a file in `lib/identity-idp-functions/$function_name.rb` so that it can be loaded as:
    ```rb
    require "identity-idp-functions/$function_name"
    ```

## Generating template.yaml

`template.yaml` is used to generate the SAM build. We dynamically generate it and ignore it from
git. To see what's generated, run:

```
./bin/generate-template
```

## Running tests

```
bundle exec rake spec
```
