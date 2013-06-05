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

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_successful_response response

    assert_equal '654321', response.authorization
    assert_equal '085114', response.params['order_id']
  end

  def test_rejected_purchase
    @gateway.expects(:ssl_post).returns(rejected_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failed_response response

    assert_equal '430285 Not authorised', response.message
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failed_response response

    assert_equal '430285 Not authorised', response.message
  end

  def test_setup_purchase
    @gateway.expects(:ssl_post).returns(setup_purchase_response)
    @options[:return_url] = 'http://example.com'

    assert response = @gateway.setup_purchase(@amount, @options)
    assert_instance_of Response, response
    assert_success response

    form_action = 'https://eu.gcsip.nl/orb/orb?ACTION=DO_START&REF=000000775200001533210000100001&MAC=SShr%2FLCml%2BCKOAPUyzVsVJsXgEQJKEBO7ZdRO4bwx8c%3D'
    assert_equal form_action, response.params['action_url']
  end

  def test_successful_details_for
    @gateway.expects(:ssl_post).returns(successful_details_response)
    ref = '000000775200001230350000100001'

    response = @gateway.details_for(ref)
    assert_successful_response response

    assert_equal '654321', response.authorization
  end

  def test_failed_details_for
    @gateway.expects(:ssl_post).returns(failed_details_response)
    ref = '000000775200001230350000100001'

    response = @gateway.details_for(ref)
    assert_failed_response response

    assert_equal '430285 Not authorised', response.message
  end


  protected


  def assert_successful_response(response)
    assert response
    assert_instance_of Response, response
    assert_success response
  end

  def assert_failed_response(response)
    assert response
    assert_instance_of Response, response
    assert_failure response
  end


  def successful_purchase_response
    headers = {}
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
      <ROW>
        <ORDERID>085114</ORDERID>
      </ROW>
    </RESPONSE>
  </REQUEST>
</XML>
    XML

    [200, headers, body]
  end

  def rejected_purchase_response
    headers = {}
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
      <STATUS>
        <STATUSDATE>20130605191248</STATUSDATE>
        <PAYMENTMETHODID>1</PAYMENTMETHODID>
        <MERCHANTREFERENCE>0000000000817442</MERCHANTREFERENCE>
        <FRAUDRESULT>A</FRAUDRESULT>
        <ATTEMPTID>1</ATTEMPTID>
        <PAYMENTREFERENCE>0</PAYMENTREFERENCE>
        <AMOUNT>100</AMOUNT>
        <EXPIRYDATE>0114</EXPIRYDATE>
        <MERCHANTID>7293</MERCHANTID>
        <ORDERID>111239</ORDERID>
        <STATUSID>100</STATUSID>
        <CREDITCARDNUMBER>************7107</CREDITCARDNUMBER>
        <FRAUDCODE>0100</FRAUDCODE>
        <EFFORTID>1</EFFORTID>
        <CVVRESULT>0</CVVRESULT>
        <CURRENCYCODE>HKD</CURRENCYCODE>
        <PAYMENTPRODUCTID>3</PAYMENTPRODUCTID>
        <ERRORS>
          <ERROR>
          <TYPE>B</TYPE>
          <CODE>430285</CODE>
          <MESSAGE>430285 Not authorised</MESSAGE>
          </ERROR>
        </ERRORS>
      </STATUS>
    </RESPONSE>
  </REQUEST>
</XML>
    XML

    [200, headers, body]
  end

  def failed_purchase_response
    headers = {}
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
        <MESSAGE>430285 Not authorised</MESSAGE>
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

  def setup_purchase_response
    headers = {}
    body = <<-XML
<?xml version="1.0" encoding="UTF-8"?>
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
        <ORDERID>153321</ORDERID>
        <MERCHANTREFERENCE>0000000000013042</MERCHANTREFERENCE>
        <AMOUNT>100</AMOUNT>
        <CURRENCYCODE>HKD</CURRENCYCODE>
        <LANGUAGECODE>en</LANGUAGECODE>
        <COUNTRYCODE>CA</COUNTRYCODE>
        <FIRSTNAME>Alice</FIRSTNAME>
        <SURNAME>Smith</SURNAME>
        <HOUSENUM>123</HOUSENUM>
        <STREET>Example Street</STREET>
        <CITY>Calgary</CITY>
        <STATE>Alberta</STATE>
        <ZIP>t3s5t5</ZIP>
      </ORDER>
      <PAYMENT>
        <HOSTEDINDICATOR>1</HOSTEDINDICATOR>
        <RETURNURL>http://localhost:4567/</RETURNURL>
        <AMOUNT>100</AMOUNT>
        <CURRENCYCODE>HKD</CURRENCYCODE>
        <LANGUAGECODE>en</LANGUAGECODE>
        <COUNTRYCODE>CA</COUNTRYCODE>
        <PAYMENTPRODUCTID>1</PAYMENTPRODUCTID>
      </PAYMENT>
    </PARAMS>
    <RESPONSE>
      <RESULT>OK</RESULT>
      <META>
        <REQUESTID>4071247</REQUESTID>
        <RESPONSEDATETIME>20130408233322</RESPONSEDATETIME>
      </META>
      <ROW>
        <STATUSDATE>20130408233322</STATUSDATE>
        <PAYMENTREFERENCE>0</PAYMENTREFERENCE>
        <ADDITIONALREFERENCE>0000000000013042</ADDITIONALREFERENCE>
        <ORDERID>153321</ORDERID>
        <EXTERNALREFERENCE>0000000000013042</EXTERNALREFERENCE>
        <EFFORTID>1</EFFORTID>
        <REF>000000775200001533210000100001</REF>
        <FORMACTION>https://eu.gcsip.nl/orb/orb?ACTION=DO_START&amp;REF=000000775200001533210000100001&amp;MAC=SShr%2FLCml%2BCKOAPUyzVsVJsXgEQJKEBO7ZdRO4bwx8c%3D</FORMACTION>
        <FORMMETHOD>GET</FORMMETHOD>
        <ATTEMPTID>1</ATTEMPTID>
        <MERCHANTID>7752</MERCHANTID>
        <STATUSID>20</STATUSID>
        <RETURNMAC>iKJ8qtxTK5giP8Ps2rutQRxrp66lnVX344MnKhS1kV8=</RETURNMAC>
        <MAC>SShr/LCml+CKOAPUyzVsVJsXgEQJKEBO7ZdRO4bwx8c=</MAC>
      </ROW>
    </RESPONSE>
  </REQUEST>
</XML>
    XML

    [200, headers, body]
  end

  def successful_details_response
    headers = {}
    body = <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<XML>
  <REQUEST>
    <ACTION>GET_ORDERSTATUS</ACTION>
    <META>
      <MERCHANTID>7293</MERCHANTID>
      <IPADDRESS>127.0.0.1</IPADDRESS>
      <VERSION>2.0</VERSION>
      <REQUESTIPADDRESS>46.16.250.68</REQUESTIPADDRESS>
    </META>
    <PARAMS>
      <ORDER>
        <ORDERID>112257</ORDERID>
        <EFFORID>1</EFFORID>
      </ORDER>
    </PARAMS>
    <RESPONSE>
      <RESULT>OK</RESULT>
      <META>
        <REQUESTID>6375130</REQUESTID>
        <RESPONSEDATETIME>20130605195807</RESPONSEDATETIME>
      </META>
      <STATUS>
        <STATUSDATE>20130605192311</STATUSDATE>
        <PAYMENTMETHODID>1</PAYMENTMETHODID>
        <MERCHANTREFERENCE>0000000000026134</MERCHANTREFERENCE>
        <FRAUDRESULT>A</FRAUDRESULT>
        <ATTEMPTID>1</ATTEMPTID>
        <AUTHORISATIONCODE>654321</AUTHORISATIONCODE>
        <PAYMENTREFERENCE>0</PAYMENTREFERENCE>
        <AMOUNT>100</AMOUNT>
        <EXPIRYDATE>0114</EXPIRYDATE>
        <MERCHANTID>7293</MERCHANTID>
        <ORDERID>112257</ORDERID>
        <STATUSID>800</STATUSID>
        <CREDITCARDNUMBER>************1111</CREDITCARDNUMBER>
        <FRAUDCODE>0100</FRAUDCODE>
        <EFFORTID>1</EFFORTID>
        <CVVRESULT>0</CVVRESULT>
        <CURRENCYCODE>HKD</CURRENCYCODE>
        <PAYMENTPRODUCTID>3</PAYMENTPRODUCTID>
      </STATUS>
    </RESPONSE>
  </REQUEST>
</XML>
    XML

    [200, headers, body]
  end

  def failed_details_response
    headers = {}
    body = <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<XML>
  <REQUEST>
    <ACTION>GET_ORDERSTATUS</ACTION>
    <META>
      <MERCHANTID>7293</MERCHANTID>
      <IPADDRESS>127.0.0.1</IPADDRESS>
      <VERSION>2.0</VERSION>
      <REQUESTIPADDRESS>46.16.250.68</REQUESTIPADDRESS>
    </META>
    <PARAMS>
      <ORDER>
        <ORDERID>111239</ORDERID>
        <EFFORID>1</EFFORID>
      </ORDER>
    </PARAMS>
    <RESPONSE>
      <RESULT>OK</RESULT>
      <META>
        <REQUESTID>6375159</REQUESTID>
        <RESPONSEDATETIME>20130605195854</RESPONSEDATETIME>
      </META>
      <STATUS>
        <STATUSDATE>20130605191248</STATUSDATE>
        <PAYMENTMETHODID>1</PAYMENTMETHODID>
        <MERCHANTREFERENCE>0000000000817442</MERCHANTREFERENCE>
        <FRAUDRESULT>A</FRAUDRESULT>
        <ATTEMPTID>1</ATTEMPTID>
        <PAYMENTREFERENCE>0</PAYMENTREFERENCE>
        <AMOUNT>100</AMOUNT>
        <EXPIRYDATE>0114</EXPIRYDATE>
        <MERCHANTID>7293</MERCHANTID>
        <ORDERID>111239</ORDERID>
        <STATUSID>100</STATUSID>
        <CREDITCARDNUMBER>************7107</CREDITCARDNUMBER>
        <FRAUDCODE>0100</FRAUDCODE>
        <EFFORTID>1</EFFORTID>
        <CVVRESULT>0</CVVRESULT>
        <CURRENCYCODE>HKD</CURRENCYCODE>
        <PAYMENTPRODUCTID>3</PAYMENTPRODUCTID>
        <ERRORS>
          <ERROR>
            <TYPE>B</TYPE>
            <CODE>430285</CODE>
            <MESSAGE>430285 Not authorised</MESSAGE>
          </ERROR>
        </ERRORS>
      </STATUS>
    </RESPONSE>
  </REQUEST>
</XML>
    XML

    [200, headers, body]
  end
end
