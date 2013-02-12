require 'test_helper'

class GlobalCollectTest < Test::Unit::TestCase
  def setup
    @gateway = GlobalCollectGateway.new(:merchant_id => '4567')
    @credit_card = credit_card
    @amount = 100

    @options = {
      :order_id => Time.now.strftime('%H%M%S'),
      :merchant_ref => '%06d' % rand(1_000),
      :currency => 'CAD', :language => 'en', :country => 'CA'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)


    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response

    assert_success response
    assert_equal '654321', response.authorization

    # assert response.test?
  end

  def test_unsuccessful_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response

    assert_failure response
    assert_equal 'Not authorised', response.message

    # assert response.test?
  end

  protected

  def successful_purchase_response
    headers = { }
    body = <<-XML
<XML>
  <REQUEST>
    <ACTION>INSERT_ORDERWITHPAYMENT</ACTION>
    <META>
      <MERCHANTID>1234</MERCHANTID>
      <IPADDRESS>127.0.0.1</IPADDRESS>
      <VERSION>1.0</VERSION>
      <REQUESTIPADDRESS>127.0.0.1</REQUESTIPADDRESS>
    </META>
    <PARAMS>
      <ORDER>
        <ORDERID>085114</ORDERID>
        <MERCHANTREFERENCE>0000000000592258</MERCHANTREFERENCE>
        <AMOUNT>100</AMOUNT>
        <CURRENCYCODE>HKD</CURRENCYCODE>
        <LANGUAGECODE>en</LANGUAGECODE>
        <COUNTRYCODE>CA</COUNTRYCODE>
      </ORDER>
      <PAYMENT>
        <PAYMENTPRODUCTID>3</PAYMENTPRODUCTID>
        <AMOUNT>100</AMOUNT>
        <CURRENCYCODE>HKD</CURRENCYCODE>
        <LANGUAGECODE>en</LANGUAGECODE>
        <COUNTRYCODE>CA</COUNTRYCODE>
        <CREDITCARDNUMBER>4444333322221111</CREDITCARDNUMBER>
        <EXPIRYDATE>0115</EXPIRYDATE>
        <CVV>123</CVV>
      </PAYMENT>
    </PARAMS>
    <RESPONSE>
      <RESULT>OK</RESULT>
      <META>
        <REQUESTID>711237</REQUESTID>
        <RESPONSEDATETIME>20130208165117</RESPONSEDATETIME>
      </META>
      <ROW>
        <STATUSDATE>20130208165117</STATUSDATE>
        <FRAUDRESULT>A</FRAUDRESULT>
        <AUTHORISATIONCODE>654321</AUTHORISATIONCODE>
        <PAYMENTREFERENCE>0</PAYMENTREFERENCE>
        <ADDITIONALREFERENCE>0000000000592258</ADDITIONALREFERENCE>
        <ORDERID>085114</ORDERID>
        <EXTERNALREFERENCE>0000000000592258</EXTERNALREFERENCE>
        <FRAUDCODE>0100</FRAUDCODE>
        <EFFORTID>1</EFFORTID>
        <CVVRESULT>0</CVVRESULT>
        <ATTEMPTID>1</ATTEMPTID>
        <MERCHANTID>1234</MERCHANTID>
        <STATUSID>800</STATUSID>
      </ROW>
    </RESPONSE>
  </REQUEST>
</XML>
    XML

    [200, headers, body]
  end

  def failed_purchase_response
    headers= { }
    body = <<-XML
<XML>
  <REQUEST>
    <ACTION>INSERT_ORDERWITHPAYMENT</ACTION>
    <META>
      <MERCHANTID>1234</MERCHANTID>
      <IPADDRESS>127.0.0.1</IPADDRESS>
      <VERSION>1.0</VERSION>
      <REQUESTIPADDRESS>46.16.250.68</REQUESTIPADDRESS>
    </META>
    <PARAMS>
      <ORDER>
        <ORDERID>085033</ORDERID>
        <MERCHANTREFERENCE>0000000000438559</MERCHANTREFERENCE>
        <AMOUNT>100</AMOUNT>
        <CURRENCYCODE>HKD</CURRENCYCODE>
        <LANGUAGECODE>en</LANGUAGECODE>
        <COUNTRYCODE>CA</COUNTRYCODE>
      </ORDER>
      <PAYMENT>
        <PAYMENTPRODUCTID>3</PAYMENTPRODUCTID>
        <AMOUNT>100</AMOUNT>
        <CURRENCYCODE>HKD</CURRENCYCODE>
        <LANGUAGECODE>en</LANGUAGECODE>
        <COUNTRYCODE>CA</COUNTRYCODE>
        <CREDITCARDNUMBER>4263982640269299</CREDITCARDNUMBER>
        <EXPIRYDATE>0114</EXPIRYDATE>
        <CVV>837</CVV>
      </PAYMENT>
    </PARAMS>
    <RESPONSE>
      <RESULT>NOK</RESULT>
      <META>
        <REQUESTID>711228</REQUESTID>
        <RESPONSEDATETIME>20130208165036</RESPONSEDATETIME>
      </META>
      <ERROR>
        <CODE>430285</CODE>
        <MESSAGE>Not authorised</MESSAGE>
      </ERROR>
      <ROW>
        <CVVRESULT>M</CVVRESULT>
        <FRAUDRESULT>A</FRAUDRESULT>
        <FRAUDCODE>0150</FRAUDCODE>
        <AUTHORISATIONCODE/>
      </ROW>
    </RESPONSE>
  </REQUEST>
</XML>
    XML

    [200, headers, body]
  end

end
