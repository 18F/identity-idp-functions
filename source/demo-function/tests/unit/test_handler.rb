require 'json'
require 'test/unit'
require 'mocha/test_unit'

require_relative '../../src/app'

class DemoFunctionTest < Test::Unit::TestCase
  def event
    {
      
    }
  end

  def mock_response
    Object.new.tap do |mock|
      mock.expects(:code).returns(200)
      mock.expects(:body).returns('1.1.1.1')
    end
  end

  def expected_result
    {
      statusCode: 200,
      body: {
        message: 'Hello World!',
        location: '1.1.1.1'
      }.to_json
    }
  end

  def test_lambda_handler
    HTTParty.expects(:get).with('http://checkip.amazonaws.com/').returns(mock_response)
    assert_equal(lambda_handler(event: event, context: ''), expected_result)
  end
end
