# identity-idp-functions
IDP Lambda Functions for login.gov

## Usage

As a gem:

```ruby
gem 'identity-idp-functions', require: 'identity/idp/functions', github: '18f/identity-idp-functions'
```

Calling a handler directly

```ruby
Identity::Idp::Functions::DemoFunction::Handler.handle(
  event: event,
  context: context
)
```

## Adding a new Lambda

- Lambdas should have an entry point at `source/$function_name/lib/$function_name.rb`

## Running tests

```
bundle exec rake spec
```
