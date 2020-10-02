# identity-idp-functions
IDP Lambda Functions for login.gov

## Usage

As a gem:

```ruby
gem 'identity-idp-functions', github: '18f/identity-idp-functions'
```

Calling a handler directly

```ruby
require 'identity-idp-functions'

IdentityIdpFunctions::DemoFunction.handle(
  event: event,
  context: context
)
```

Expected local development workflow is with a block:

```ruby
IdentityIdpFunctions::ProofAddress.handle(event: event, context: context) do |result|
  store(result[:address_result])
end
```

## Adding a new Lambda

- Lambdas should have an entry point at `source/$function_name/lib/$function_name.rb`
- Update `source/template.yaml` to add the required metadata about the lambda. Copy `DemoFunction` and replace all the various cases of its name (`demo_function`, `Demo Function`, `DemoFunction`)

## Running tests

```
bundle exec rake spec
```
