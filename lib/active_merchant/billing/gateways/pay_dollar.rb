require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayDollarGateway < Gateway
      self.test_url = 'https://test.paydollar.com/b2cDemo/eng/dPayment/payComp.jsp'
      self.live_url = 'https://www.paydollar.com/b2c2/eng/dPayment/payComp.jsp'

      # PayDollar uses 12.34 format for payment
      self.money_format = :dollars

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US', 'HK']

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :diners, :jcb]

      # The homepage URL of the gateway
      self.homepage_url = 'http://www.paydollar.com/'

      # The name of the gateway
      self.display_name = 'PayDollar'


      CARD_BRANDS = {
        'visa'   => 'VISA',
        'master' => 'Master',
        'diners' => 'Diners',
        'jcb'    => 'JCB'
      }

      CURRENCY_CODES = {
        'HKD' => '344',
        'USD' => '840',
        'SGD' => '702',
        'CNY' => '156',
        'RMB' => '156',
        'JPY' => '392',
        'TWD' => '901',
        'AUD' => '036',
        'EUR' => '978',
        'GBP' => '826',
        'CAD' => '124'
      }

      PURCHASE = 'N'
      AUTHORIZE = 'H'

      STATUS_OK = (200...300)
      STATUS_REDIRECT = (300...400)

      def initialize(options = {})
        requires!(options, :merchant_id, :success_url, :fail_url, :error_url)
        @options = options
        super
      end

      # Public: Authorizes a purchase but does not capture it.
      # Returns a regular Response object.
      def authorize(amount_in_cents, credit_card, options = {})
        post = post_data(AUTHORIZE, options)
        post[:amount] = amount(amount_in_cents)
        add_invoice(post, options)
        add_credit_card(post, credit_card)

        commit(AUTHORIZE, post)
      end

      # Public: Makes a purchase, capturing the money immediately.
      # Returns a regular Response object.
      def purchase(amount_in_cents, credit_card, options = {})
        post = post_data(PURCHASE, options)
        post[:amount] = amount(amount_in_cents)
        add_invoice(post, options)
        add_credit_card(post, credit_card)

        commit(PURCHASE, post)
      end


      private


      # Internal: Generates basic post data required for PayDollar.
      def post_data(action, parameters = {})
        data = PostData.new
        data[:merchantId] = @options[:merchant_id]
        data[:failUrl] = @options[:fail_url]
        data[:successUrl] = @options[:success_url]
        data[:errorUrl] = @options[:error_url]

        data
      end

      # Internal: Adds invoice details to post data.
      def add_invoice(post, options)
        post[:orderRef] = options[:order_id]
        # Hard-coded to HKD/344 until another merchant uses PayDollar.
        post[:currCode] = '344'
        # Hard-coded to E/English until another merchant uses PayDollar.
        post[:lang] = 'E'
      end

      # Internal: Adds credit card details to post data.
      def add_credit_card(post, credit_card)
        post[:pMethod] = CARD_BRANDS[credit_card.brand]
        post[:cardHolder] = [credit_card.first_name, credit_card.last_name].join(' ')
        post[:cardNo] = credit_card.number.to_s
        post[:epMonth] = credit_card.month.to_s
        post[:epYear] = credit_card.year.to_s
        post[:securityCode] = credit_card.verification_value.to_s
      end

      # Internal: Sends an SSL request and returns the response object.
      def commit(action, data)
        headers = {}
        data[:payType] = action

        raw_response = ssl_post(endpoint, data.to_post_data, headers)
        handle_response(*raw_response)
      end

      # Internal: Returns the endpoint to contact based on test mode.
      def endpoint
        test? ? test_url : live_url
      end

      # Internal: Delegates how to handle the two response types that
      # PayDollar returns. 
      #
      # Successful and Rejected purchases are returned as 200 responses
      # with an HTML blob that contains a redirect.
      #
      # Errors, like expired card, etc, are returned as a 302 redirect
      # with an error message in the query params.
      def handle_response(status, headers, body)
        case status
        when STATUS_OK then handle_ok(headers, body)
        when STATUS_REDIRECT then handle_redirect(headers, body)
        end
      end

      # Internal: Handles a 2XX response.
      #
      # The data sent from PayDollar includes a JS driven redirect.
      # It's not clear if this must be followed in order to complete
      # the transaction with PayDollar.
      def handle_ok(headers, body)
        html = Nokogiri::HTML(body)
        authorization = html.css('input[name=oId]').first['value']
        redirect_url = html.css('input[name=urlRedirect]').first['value']

        success = success_for(redirect_url)
        message = message_for(success, redirect_url)
        params = {}
        options = response_options(authorization)

        Response.new(success, message, params, options)
      end

      # Internal: Handles a 3XX response.
      def handle_redirect(headers, body)
        redirect_url = location_for(headers)
        success = false
        message = message_for(success, redirect_url)

        params = {}
        options = response_options

        Response.new(success, message, params, options)
      end

      # Internal: Returns whether redirect URL is successful.
      def success_for(path)
        !! path.include?(@options[:success_url])
      end

      # Internal: Extracts and returns message from redirect URL.
      def message_for(success, path)
        return 'Success' if success

        uri = URI.parse(path)
        query = CGI.parse(uri.query)
        query['errorMsg'].first || 'Failed'
      end

      # Internal: Extracts and returns a redirect URL from response headers.
      def location_for(headers)
        # URIs from PayDollar are not properly escaped.
        location = String(headers['location'].first)
        location.gsub(' ', '%20')
      end

      # Internal: Returns options for ActiveMerchant::Billing::Response
      def response_options(authorization = nil)
        {
          :test => true,
          :authorization => authorization,
          :fraud_review => false,
          :avs_result => nil,
          :cvv_result => nil
        }
      end

      # Internal: Executes an SSL request and returns a more Rack-like
      # response format because PayDollar's response code is
      # informative.
      def ssl_post(endpoint, data, headers = {})
        response = raw_ssl_request(:post, endpoint, data, headers)
        [response.code.to_i, response.to_hash, response.body]
      end
    end
  end
end

