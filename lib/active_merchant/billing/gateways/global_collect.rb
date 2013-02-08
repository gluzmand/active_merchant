require 'builder'
require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class GlobalCollectGateway < Gateway
      self.test_url = 'https://test.paydollar.com/b2cDemo/eng/dPayment/payComp.jsp'
      # self.live_url = 'https://www.paydollar.com/b2c2/eng/dPayment/payComp.jsp'
      self.live_url = 'https://test.paydollar.com/b2cDemo/eng/dPayment/payComp.jsp'

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
        requires!(options, :order_id, :amount, :currency)
        data = build_request(options)
        ssl_post('', data, headers)
      end


      protected


      # Internal: Executes an SSL request and returns a more Rack-like
      # response format because PayDollar's response code is
      # informative.
      def ssl_post(endpoint, data, headers = {})
        response = raw_ssl_request(:post, endpoint, data, headers)
        [response.code.to_i, response.to_hash, response.body]
      end

      def build_request(options)
        internal_order_id = options[:order_id]
        gateway_order_id = pseudo_serial_order_id(internal_order_id)

        amount = options[:amount]
        currency = options[:currency]
        first_name = options

        builder = Builder::XmlMarkup.new
        builder.XML { |xml|
          xml.REQUEST { |request|
            request.ACTION("INSERT_ORDERWITHPAYMENT");
            request.META { |meta|
              # These values appear to be optional.
              meta.MERCHANTID(@options[:merchant_id])
              meta.IPADDRESS('127.0.0.1')
              meta.VERSION('1.0')
            }
            request.PARAMS { |params|
              params.ORDER { |order|
                order.ORDERID(gateway_order_id)
                order.MERCHANTREFERENCE(internal_order_id)
                order.AMOUNT(amount)
                order.CURRENCYCODE(currency)
                order.LANGUAGECODE(language)
                order.COUNTRYCODE(country)
                order.FIRSTNAME(first_name)
                order.SURNAME(last_name)
                # order.HOUSENUM('123')
                order.STREET(billing_address_)
                order.CITY(billing_city)
                order.STATE(billing_state)
                order.ZIP(billing_postal_code)
              }
              params.PAYMENT { |payment|
                payment.PAYMENTPRODUCTID(GlobalCollect::CreditCards::MASTER_CARD)
                payment.AMOUNT('100')
                payment.CURRENCYCODE('HKD')
                payment.LANGUAGECODE('en')
                payment.COUNTRYCODE('CA')
                payment.CREDITCARDNUMBER('4444333322221111')
                payment.EXPIRYDATE('0115')
                payment.CVV('123')
              }
            }
          }
        }
      end

      # The order number for GlobalCollect needs to be unique between
      # transactions, rather than keeping a counter around we'll just
      # join the order id and current time. Should be good enough.
      def pseudo_serial_order_id(order_id)
        payment_time = Time.now.sprintf('%H%M%S')
        gateway_order_id = "#{internal_order_id}#{payment_time}"

      end


    end
  end
end
