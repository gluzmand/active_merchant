require 'test_helper'

class RemotePayDollarTest < Test::Unit::TestCase


  def setup
    @gateway = PayDollarGateway.new(fixtures(:pay_dollar))

    @amount = 100.0
    @credit_card = credit_card('4918914107195005', :year => '2015', :month => '07')
    @declined_card = credit_card('4000300011112220')

    t = Time.now
    @options = {
      # The order id must be unique for PayDollar.
      :order_id => "#{t.to_i}:#{t.usec}",
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
    attrs = fixtures(:pay_dollar)
    attrs[:merchant_id] = 'INVALID'
    gateway = PayDollarGateway.new(attrs)
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Parameter Merchant Id Incorrect', response.message
  end
end
