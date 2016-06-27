require 'json'
require 'http'

module Spree
  OrdersController.class_eval do
    before_action :load_boleta, :only => [:show]

    def load_boleta
      boleta_factura = BoletaFactura.find_by_factura(params[:id])
      @boleta = getBoleta(boleta_factura['boleta'])[0]
    end

    def getBoleta(idBoleta)
      response = get(ENV["general_system_url"] + "facturas/" + idBoleta.to_s)

      bill = JSON.parse(response.body)
      return bill
    rescue JSON::ParserError
      return {}
    end

    def get(uri, hmac=nil)
      uri = URI.parse(uri)
      http = Net::HTTP.new(uri.host, uri.port)

      request = Net::HTTP::Get.new(uri.request_uri, initheader = {'Content-Type' => 'application/json'})
      if hmac
        request["Authorization"] = hmac
      end

      return http.request(request)
    end
  end
end
