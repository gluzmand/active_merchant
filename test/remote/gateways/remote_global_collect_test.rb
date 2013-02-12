require 'test_helper'

# GlobalCollect uses white-listed IP addresses for test server
# authentication, so these tests assume you are on that list.

class RemoteGlobalCollectTest < Test::Unit::TestCase
  def setup
    @gateway = GlobalCollectGateway.new(fixtures(:global_collect))
    @purchase_options = {
      :order_id => Time.now.to_i,
      :currency => 'HKD',
      :language => 'en',
      :country => 'CA'
    }
  end

  def test_successful_purchase
    credit_card = credit_card('4444333322221111', :year => '2015', :month => '01')

    assert response = @gateway.purchase(1000, credit_card, @purchase_options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_failed_purchase
    credit_card = credit_card('4917484589897107', :year => '2014', :month => '04')

    assert response = @gateway.purchase(1000, credit_card, @purchase_options)
    assert_failure response
    assert_equal 'Card expired', response.message
  end

  def x_test_invalid_credentials
    # Not sure how to test this with the IP white-listing.
  end

end
