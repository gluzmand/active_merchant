require 'test_helper'

class RemotePayDollarTest < Test::Unit::TestCase


  def setup
    @gateway = PayDollarGateway.new(fixtures(:pay_dollar))

    @amount = 100
    @credit_card = credit_card('4000100011112224')
    @declined_card = credit_card('4000300011112220')

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  # Need a proper test account to go any further.
  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Failed', response.message
  end

  def xtest_authorize_and_capture
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Success', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization)
    assert_success capture
  end

  def xtest_failed_capture
    assert response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'REPLACE WITH GATEWAY FAILURE MESSAGE', response.message
  end

  def test_invalid_login
    gateway = PayDollarGateway.new(
                :merchant_id => '',
                :success_url => 'http://example.com/success',
                :fail_url => 'http://example.com/fail',
                :error_url => 'http://example.com/error',
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Parameter Merchant Id Incorrect', response.message
  end
end
