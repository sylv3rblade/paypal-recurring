module PayPal
  module Recurring
    class Request
      METHODS = {
        :checkout       => "SetExpressCheckout",
        :payment        => "DoExpressCheckoutPayment",
        :details        => "GetExpressCheckoutDetails",
        :create_profile => "CreateRecurringPaymentsProfile",
        :profile        => "GetRecurringPaymentsProfileDetails",
        :manage_profile => "ManageRecurringPaymentsProfileStatus",
        :update_profile => "UpdateRecurringPaymentsProfile",
        :refund         => "RefundTransaction"
      }

      INITIAL_AMOUNT_ACTIONS = {
        :cancel   => "CancelOnFailure",
        :continue => "ContinueOnFailure"
      }

      ACTIONS = {
        :cancel     => "Cancel",
        :suspend    => "Suspend",
        :reactivate => "Reactivate"
      }

      PERIOD = {
        :daily   => "Day",
        :weekly  => "Weekly",
        :monthly => "Month",
        :yearly  => "Year"
      }

      TRIAL_PERIOD = {
        :daily    => "Day",
        :weekly   => "Weekly",
        :monthly  => "Month",
        :yearly   => "Year"
      }

      OUTSTANDING = {
        :next_billing => "AddToNextBilling",
        :no_auto      => "NoAutoBill"
      }

      REFUND_TYPE  = {
        :full     => "Full",
        :partial  => "Partial",
        :external => "ExternalDispute",
        :other    => "Other"
      }

      # http://www.paypalobjects.com/en_US/ebook/PP_NVPAPI_DeveloperGuide/Appx_fieldreference.html
      ATTRIBUTES = {
        :action                => "ACTION",
        :amount                => ["PAYMENTREQUEST_0_AMT", "AMT"],
        :billing_type          => "L_BILLINGTYPE0",
        :brand_name            => "BRANDNAME",
        :cancel_url            => "CANCELURL",
        :currency              => ["PAYMENTREQUEST_0_CURRENCYCODE", "CURRENCYCODE"],
        :description           => ["DESC", "PAYMENTREQUEST_0_DESC", "L_BILLINGAGREEMENTDESCRIPTION0"],
        :first_name            => "FIRSTNAME",
        :note                  => "NOTE",
        :item_category         => "L_PAYMENTREQUEST_0_ITEMCATEGORY0",
        :item_name             => "L_PAYMENTREQUEST_0_NAME0",
        :item_amount           => "L_PAYMENTREQUEST_0_AMT0",
        :item_quantity         => "L_PAYMENTREQUEST_0_QTY0",
        :email                 => "EMAIL",
        :failed                => "MAXFAILEDPAYMENTS",
        :frequency             => "BILLINGFREQUENCY",
        :initial_amount        => "INITAMT",
        :initial_amount_action => "FAILEDINITAMTACTION",
        :ipn_url               => ["PAYMENTREQUEST_0_NOTIFYURL", "NOTIFYURL"],
        :landing_page          => "LANDINGPAGE",
        :last_name             => "LASTNAME",
        :locale                => "LOCALECODE",
        :method                => "METHOD",
        :no_shipping           => "NOSHIPPING",
        :outstanding           => "AUTOBILLOUTAMT",
        :password              => "PWD",
        :payer_id              => "PAYERID",
        :payment_action        => "PAYMENTREQUEST_0_PAYMENTACTION",
        :period                => "BILLINGPERIOD",
        :profile_id            => "PROFILEID",
        :reference             => ["PROFILEREFERENCE", "PAYMENTREQUEST_0_CUSTOM", "PAYMENTREQUEST_0_INVNUM"],
        :refund_type           => "REFUNDTYPE",
        :return_url            => "RETURNURL",
        :signature             => "SIGNATURE",
        :start_at              => "PROFILESTARTDATE",
        :token                 => "TOKEN",
        :transaction_id        => "TRANSACTIONID",
        :trial_amount          => "TRIALAMT",
        :trial_frequency       => "TRIALBILLINGFREQUENCY",
        :trial_length          => "TRIALTOTALBILLINGCYCLES",
        :trial_period          => "TRIALBILLINGPERIOD",
        :username              => "USER",
        :version               => "VERSION",
        :custom                => "PAYMENTREQUEST_0_CUSTOM"
      }

      CA_FILE = File.dirname(__FILE__) + "/cacert.pem"

      attr_accessor :uri

      # Do a POST request to PayPal API.
      # The +method+ argument is the name of the API method you want to invoke.
      # For instance, if you want to request a new checkout token, you may want
      # to do something like:
      #
      #   response = request.run(:express_checkout)
      #
      # We normalize the methods name. For a list of what's being covered, refer to
      # PayPal::Recurring::Request::METHODS constant.
      #
      # The params hash can use normalized names. For a list, check the
      # PayPal::Recurring::Request::ATTRIBUTES constant.
      #
      def run(method, params = {})
        params = prepare_params(params.merge(:method => METHODS.fetch(method, method.to_s)))
        response = post(params)
        Response.process(method, response)
      end

      #
      #
      def request
        @request ||= Net::HTTP::Post.new(uri.request_uri).tap do |http|
          http["User-Agent"] = "PayPal::Recurring/#{PayPal::Recurring::Version::STRING}"
        end
      end

      #
      #
      def post(params = {})
        request.form_data = params
        client.request(request)
      end

      # Join params and normalize attribute names.
      #
      def prepare_params(params) # :nodoc:
        normalize_params default_params.merge(params)
      end

      # Parse current API url.
      #
      def uri # :nodoc:
        @uri ||= URI.parse(PayPal::Recurring.api_endpoint)
      end

      def client
        @client ||= begin
          Net::HTTP.new(uri.host, uri.port).tap do |http|
            http.use_ssl = true
            http.verify_mode = OpenSSL::SSL::VERIFY_PEER
            http.ca_file = CA_FILE
          end
        end
      end

      def default_params
        {
          :username    => PayPal::Recurring.username,
          :password    => PayPal::Recurring.password,
          :signature   => PayPal::Recurring.signature,
          :version     => PayPal::Recurring.api_version
        }
      end

      def normalize_params(params)
        params.inject({}) do |buffer, (name, value)|
          attr_names = [ATTRIBUTES[name.to_sym]].flatten.compact
          attr_names << name if attr_names.empty?

          attr_names.each do |attr_name|
            buffer[attr_name.to_sym] = respond_to?("build_#{name}") ? send("build_#{name}", value) : value
          end

          buffer
        end
      end

      def build_period(value) # :nodoc:
        PERIOD.fetch(value.to_sym, value) if value
      end

      def build_trial_period(value)
        TRIAL_PERIOD.fetch(value.to_sym, value) if value
      end

      def build_start_at(value) # :nodoc:
        value.respond_to?(:strftime) ? value.strftime("%Y-%m-%dT%H:%M:%SZ") : value
      end

      def build_outstanding(value) # :nodoc:
        OUTSTANDING.fetch(value.to_sym, value) if value
      end

      def build_refund_type(value) # :nodoc:
        REFUND_TYPE.fetch(value.to_sym, value) if value
      end

      def build_action(value) # :nodoc:
        ACTIONS.fetch(value.to_sym, value) if value
      end

      def build_initial_amount_action(value) # :nodoc:
        INITIAL_AMOUNT_ACTIONS.fetch(value.to_sym, value) if value
      end

      def build_locale(value) # :nodoc:
        value.to_s.upcase
      end
    end
  end
end
