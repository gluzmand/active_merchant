require 'builder'
require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class GlobalCollectGateway < Gateway
      self.test_url = 'https://ps.gcsip.nl/wdl/wdl'
      # self.live_url = 'https://ps.gcsip.nl/wdl/wdl'
      self.live_url = 'https://ps.gcsip.com/wdl/wdl'

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

      STATUS_PENDING_AT_MERCHANT = '20'.freeze
      STATUS_PENDING_AT_GLOBAL_COLLECT = '25'.freeze
      STATUS_REJECTED = '100'.freeze
      STATUS_READY = '800'.freeze

      CURRENCY_CODES = { }
      COUNTRY_CODES = { }

      def initialize(options = {})
        requires!(options, :merchant_id)
        @options = options
        super
      end

      # Make a purchase directly using the base MerchantLink API.
      def purchase(amount_in_cents, credit_card, options = {})
        options[:amount] = amount_in_cents

        # Using Builder for the XML is a bit weird, so the part of the
        # tree needed is yielded for additional values.
        data = build_request('INSERT_ORDERWITHPAYMENT', options) do |params_xml|
          add_invoice(params_xml, options)
          add_credit_card(params_xml, credit_card, options)
        end

        commit(data)
      end

      # Prepare an order for purchase, the result is a URL to redirect
      # the customer to so they can complete the purchase with their
      # payment details.
      def setup_purchase(amount_in_cents, options = {})
        requires!(options, :return_url)

        options[:amount] = amount_in_cents

        data = build_request('INSERT_ORDERWITHPAYMENT', options) do |params_xml|
          add_redirect(params_xml, options)
          add_invoice(params_xml, options)
        end

        commit(data)
      end

      # Fetch the results of a purchase via the reference provided.
      # This is used by the HostedMerchantLink API during the customer
      # redirect after payment.
      def details_for(ref, options = {})
        data = build_request('GET_ORDERSTATUS', options) do |params_xml|
          add_reference(params_xml, ref)
        end

        commit(data)
      end


      protected



      # REQUEST BUILDING
      # ================

      def build_request(action, options)
        merchant_reference = options[:merchant_reference]
        api_version = case action
                      when 'GET_ORDERSTATUS' then '2.0'
                      else '1.0'
                      end

        builder = Builder::XmlMarkup.new
        builder.XML { |xml|
          xml.REQUEST { |request|
            request.ACTION(action);
            request.META { |meta|
              # These values appear to be optional.
              meta.MERCHANTID(@options[:merchant_id])
              meta.IPADDRESS(@options[:ip_address])
              meta.VERSION(api_version)
            }
            request.GENERAL { |general|
              general.MERCHANTREFERENCE(merchant_reference)
            }
            request.PARAMS { |params|
              yield params if block_given?
            }
          }
        }
      end

      def add_invoice(xml, options)
        requires!(options, :order_id, :currency, :amount, :language, :country)

        order_id = options[:order_id]
        merchant_reference = options[:order_id]

        xml.ORDER { |order|
          order.ORDERID(order_id)
          order.MERCHANTREFERENCE(merchant_reference)
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
        requires!(options, :amount, :currency, :language, :country)

        card_month = '%02d' % credit_card.month
        card_year = credit_card.year.to_s[-2,2]
        card_expiry = "#{card_month}#{card_year}"

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

      def add_redirect(xml, options)
        requires!(options, :return_url, :amount, :currency, :language, :country)

        return_url = options[:return_url]

        xml.PAYMENT { |payment|
          payment.HOSTEDINDICATOR(1)
          payment.RETURNURL(return_url)

          payment.AMOUNT(options[:amount])
          payment.CURRENCYCODE(options[:currency])
          payment.LANGUAGECODE(options[:language])
          payment.COUNTRYCODE(options[:country])

          # Currently there is no way for the customer to pick their
          # payment method through the checkout, so this is hard-coded.
          # The payment API doesn't seem to care whether this value
          # agrees with the card number actually entered by the
          # customer. I suspect it's only here so the customer can see
          # what cards are useable for payment. Hopefully this isn't
          # just an artifact of the test server.
          payment.PAYMENTPRODUCTID(CARD_BRANDS['visa'])
        }
      end

      def add_reference(xml, ref)
        order_id = ref[10,10].gsub(/^0*/, '')
        effort_id = ref[20,5].gsub(/^0*/, '')

        xml.ORDER { |order|
          order.ORDERID(order_id)
          order.EFFORTID(effort_id)
        }
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
        body = sanitize(body)

        xml = Nokogiri::XML(body)
        response_xml = xml.xpath('/XML/REQUEST/RESPONSE').first
        result = response_xml.xpath('RESULT').text

        case result
        when 'OK' then handle_success(headers, response_xml)
        when 'NOK' then handle_failure(headers, response_xml)
        end
      end

      # Internal: Removes sensitive data from the response body before
      # sending it anywhere else.
      def sanitize(xml)
        xml.gsub(%r{<CREDITCARDNUMBER>.+</CREDITCARDNUMBER>},'<CREDITCARDNUMBER>OMITTED</CREDITCARDNUMBER>')
           .gsub(%r{<EXPIRYDATE>.+</EXPIRYDATE>}, '<EXPIRYDATE>OMITTED</EXPIRYDATE>')
           .gsub(%r{<CVV>.+</CVV>}, '<CVV>OMITTED</CVV>')
      end

      # Internal: Handles a successful request/response.
      def handle_success(headers, response_xml)
        success = response_success(response_xml)
        message = response_message(response_xml)
        params = response_params(response_xml)
        options = response_options(response_xml)

        Response.new(success, message, params, options)
      end

      # Internal: Handles a failed request/response.
      def handle_failure(headers, response_xml)
        success = false
        message = error_message(response_xml)
        params = response_params(response_xml)
        options = response_options(response_xml)

        Response.new(success, message, params, options)
      end

      def response_success(response_xml)
        case response_xml.xpath('//STATUSID').text
        when STATUS_READY then true
        when STATUS_REJECTED then false
        else false
        end
      end

      def response_message(response_xml)
        case response_xml.xpath('//STATUSID').text
        when STATUS_PENDING_AT_MERCHANT then 'Pending'
        when STATUS_PENDING_AT_GLOBAL_COLLECT then 'Cancelled'
        when STATUS_READY then 'Success'
        else error_message(response_xml)
        end
      end


      def response_params(response_xml)
        authorization_code = response_xml.xpath('//AUTHORISATIONCODE').text
        order_id = response_xml.xpath('//ORDERID').first.try(:text)
        status = response_xml.xpath('//STATUSID').first.try(:text)
        action_url = response_xml.xpath('//FORMACTION').text

        { :xml => response_xml.to_s,
          :authorization_code => authorization_code,
          :order_id => order_id,
          :status => status,
          :action_url => action_url }.reject { |k,v| v.blank? }
      end

      # Internal: Returns options for ActiveMerchant::Billing::Response
      def response_options(response_xml)
        authorization = response_xml.xpath('//AUTHORISATIONCODE').text
        fraud_review = response_xml.xpath('//FRAUDRESULT').text
        avs_result = response_xml.xpath('//AVSRESULT').text
        cvv_result = response_xml.xpath('//CVVRESULT').text

        # ActiveMerchant doesn't like empty strings.
        avs_result = nil if avs_result.blank?
        cvv_result = nil if cvv_result.blank?

        {
          :test => self.test?,
          :authorization => authorization,
          :fraud_review => fraud_review,
          :avs_result => avs_result,
          :cvv_result => cvv_result
        }
      end

      def error_message(response_xml)
        errors = response_xml.xpath('//ERROR')
        return 'Unknown error' if errors.empty?

        code = errors.xpath('CODE').text
        message = errors.xpath('MESSAGE').text

        "#{code}: #{message}"
        message
      end

    end
  end
end
