module PayPal
  module Recurring
    module Response
      class Details < Base
        mapping(
          :status       => :CHECKOUTSTATUS,
          :email        => :EMAIL,
          :payer_id     => :PAYERID,
          :payer_status => :PAYERSTATUS,
          :first_name   => :FIRSTNAME,
          :last_name    => :LASTNAME,
          :country      => :COUNTRYCODE,
          :currency     => :CURRENCYCODE,
          :amount       => :AMT,
          :description  => :DESC,
          :ipn_url      => :NOTIFYURL,
          :custom       => :CUSTOM
        )

        def agreed?
          params[:BILLINGAGREEMENTACCEPTEDSTATUS] == "1"
        end
      end
    end
  end
end
