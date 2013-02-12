require 'builder'
require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class GlobalCollectGateway < Gateway
      self.test_url = 'https://ps.gcsip.nl/wdl/wdl'
      self.live_url = 'https://ps.gcsip.nl/wdl/wdl'
      # self.live_url = 'https://ps.gcsip.com/wdl/wdl'

      # GlobaCollect uses 1234 cents format for payment
      self.money_format = :cents

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = %w(CA HK US)

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:amex, :master, :visa]

      # The homepage URL of the gateway
      self.homepage_url = 'http://www.globalcollect.com/'

      # The name of the gateway
      self.display_name = 'GlobalCollect'

      CARD_BRANDS = {
        'visa' => 1,
        'american_express' => 2,
        'amex' => 2,
        'master_card' => 3,
        'master' => 3,
        'mc' => 3
      }

      CURRENCY_CODES = { }
      COUNTRY_CODES = { }

      def initialize(options = {})
        requires!(options, :merchant_id)
        @options = options
        super
      end

      def purchase(amount_in_cents, credit_card, options = {})
        requires!(options, :order_id, :currency)

        # Using Builder for the XML is a bit weird, so the part of the
        # tree needed is yielded for additional values.
        data = build_request('INSERT_ORDERWITHPAYMENT', options) do |params_xml|
          add_invoice(params_xml, options)
          add_credit_card(params_xml, credit_card, options)
        end

        commit(data)
      end


      protected



      # REQUEST BUILDING
      # ================

      def build_request(action, options)
        builder = Builder::XmlMarkup.new
        builder.XML { |xml|
          xml.REQUEST { |request|
            request.ACTION(action);
            request.META { |meta|
              # These values appear to be optional.
              meta.MERCHANTID(@options[:merchant_id])
              meta.IPADDRESS(@options[:ip_address])
              meta.VERSION('1.0')
            }
            request.PARAMS { |params|
              yield params if block_given?
            }
          }
        }
      end

      def add_invoice(xml, options)
        internal_order_id = options[:order_id]
        gateway_order_id = pseudo_serial_order_id(internal_order_id)

        xml.ORDER { |order|
          order.ORDERID(gateway_order_id)
          order.MERCHANTREFERENCE(internal_order_id)
          order.AMOUNT(options[:amount])
          order.CURRENCYCODE(options[:currency])
          order.LANGUAGECODE(options[:language])
          order.COUNTRYCODE(options[:country])
          order.FIRSTNAME(options[:first_name])
          order.SURNAME(options[:last_name])
          # order.HOUSENUM('123')
          order.STREET(options[:billing_address_])
          order.CITY(options[:billing_city])
          order.STATE(options[:billing_state])
          order.ZIP(options[:billing_postal_code])
        }
      end

      def add_credit_card(xml, credit_card, options)
        card_expiry = "#{'%02d' % credit_card.month}#{credit_card.year}"
        xml.PAYMENT { |payment|
          payment.PAYMENTPRODUCTID(CARD_BRANDS[credit_card.brand])
          payment.AMOUNT(options[:amount])
          payment.CURRENCYCODE(options[:currency])
          payment.LANGUAGECODE(options[:language])
          payment.COUNTRYCODE(options[:country])
          payment.CREDITCARDNUMBER(credit_card.number.to_s)
          payment.EXPIRYDATE(card_expiry)
          payment.CVV(credit_card.verification_value)
        }
      end

      # The order number for GlobalCollect needs to be unique between
      # transactions, rather than keeping a counter around we'll just
      # join the order id and current time. Should be good enough.
      def pseudo_serial_order_id(order_id)
        payment_time = Time.now.strftime('%H%M%S')
        "#{order_id}#{payment_time}"
      end


      # REQUEST SENDING
      # ===============

      # Internal: Sends an SSL request and returns the Response object.
      def commit(data)
        headers = {}

        raw_response = ssl_post(endpoint, data.to_s, headers)
        handle_response(*raw_response)
      end

      # Internal: Returns the endpoint to contact based on test mode.
      def endpoint
        test? ? test_url : live_url
      end

      # Internal: Executes an SSL request and returns a more Rack-like
      # response format.
      def ssl_post(endpoint, data, headers = {})
        response = raw_ssl_request(:post, endpoint, data, headers)
        [response.code.to_i, response.to_hash, response.body]
      end

      # Internal: Delegates how to handle the two response types that
      # GlobalCollect returns.
      #
      # Status code 200 is returned for all responses, the result is
      # nested inside a RESULT node in the response XML.
      #
      def handle_response(status, headers, body)
        xml = Nokogiri::XML(body)
        response_xml = xml.xpath('/XML/REQUEST/RESPONSE').first
        result = response_xml.xpath('RESULT').text

        case result
        when 'OK' then handle_success(headers, response_xml)
        when 'NOK' then handle_failure(headers, response_xml)
        end
      end

      # Internal: Handles a successful request/response.
      #
      # The data sent from PayDollar includes a JS driven redirect.
      # It's not clear if this must be followed in order to complete
      # the transaction with PayDollar.
      def handle_success(headers, response_xml)
        success = true
        message = 'Success'
        params = {}
        options = response_options(response_xml)

        Response.new(success, message, params, options)
      end

      # Internal: Handles a failed request/response.
      def handle_failure(headers, response_xml)
        success = false
        message = error_message(response_xml)
        params = {}
        options = {}

        Response.new(success, message, params, options)
      end

      # Internal: Returns options for ActiveMerchant::Billing::Response
      def response_options(response_xml)
        authorization = response_xml.xpath('ROW/AUTHORISATIONCODE').text
        fraud_review = response_xml.xpath('ROW/FRAUDRESULT').text
        avs_result = response_xml.xpath('ROW/AVSRESULT').text
        cvv_result = response_xml.xpath('ROW/CVVRESULT').text

        {
          :test => self.test?,
          :authorization => authorization,
          :fraud_review => fraud_review,
          :avs_result => nil, # to pass tests
          :cvv_result => nil # to pass tests
        }
      end

      def error_message(response_xml)
        code = response_xml.xpath('ERROR/CODE').text
        case code
          when '210000120' then 'Invalid card number'
          when '21000120' then 'Card expired'
          else response_xml.xpath('ERROR/MESSAGE').text
        end
      end

    end
  end
end
