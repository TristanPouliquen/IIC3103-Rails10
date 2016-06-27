require 'json'
require "erb"
include ERB::Util

module Spree
  CheckoutController.class_eval do
    skip_before_filter :load_order, :only => [:process_gateway_return, :createBoleta]

    #We need to skip this security check Rails does in order to let the payment gateway do a postback.
    skip_before_filter :verify_authenticity_token, :only => [:process_gateway_return]

    def process_payment
      order = Order.find_by_number(params[:order_number])
      boleta_factura = BoletaFactura.find_by_factura(order['number'])
      boletaId=""
      if boleta_factura.nil?
        boleta_creation = put(ENV['general_system_url'] + 'facturas/boleta', data = {'proveedor' => ENV['id_grupo'], 'cliente' => order['email'], 'total' => order['total'].to_i})

        if boleta_creation.kind_of? Net::HTTPSuccess
          BoletaFactura.create(factura: order['number'], boleta: JSON.parse(boleta_creation.body)['_id'])
          boletaId = JSON.parse(boleta_creation.body)['_id']
        else
          flash[:error] = "An error occured in the process of your order: " + boleta_creation.body
          redirect_to '/spree/checkout/payment'
        end
      else
        boletaId = boleta_factura['boleta']
      end
      callbackURL = url_encode(ENV['group_system_url'] + 'spree/checkout/gateway_landing/' + order['number'])
      url = ENV['payment_system_url'] + '?callbackUrl='+ callbackURL + '&cancelUrl='+ callbackURL + '&boletaId=' + boletaId
      redirect_to url
    end

    #TODO? This method is more or less copied from the normal controller - so this sort
    #of this is prone to messing up updates - maybe we could use alias_method_chain or something?

    def process_gateway_return
      gateway = PaymentMethod.find_by_type("Spree::PaymentMethod::HostedPayment")
      @order, @boleta, payment_made = gateway.process_response(params)

      if @order
        if payment_made
          #Payment successfully processed
          @order.payments.clear
          payment = @order.payments.create
          payment.started_processing
          payment.amount = params[:amount] || @order.total
          payment.payment_method = gateway
          payment.complete
          @order.save

          address = Spree::Address.find(@order['ship_address_id'])
          address_string = formatAddress(address)

          @order.line_items.each do |item|
            variant = Spree::Variant.find(item['variant_id'])
            if variant.nil?
              next
            else
              sku = variant['sku']
              quantity = item['quantity']
              price = item['price']

              Thread.new do
                stock_item = StockItem.find_by_variant_id(variant['id'])
                stock_item.adjust_count_on_hand(-quantity)
                stock_item.save
                dispatchBatch(quantity, sku, price.to_i, boleta_factura[:boleta], address_string)
              end
            end
          end
        else
          @order.payments.clear
          @order.state == "canceled"
          @order.canceled_at = Time.now
        end

        if @order.next
          state_callback(:after)
        end

        if @order.completed?
          if @order.state == "complete"
            flash[:notice] = I18n.t(:order_processed_successfully)
          elsif @order.state == "canceled"
            flash[:danger] = I18n.t(:payment_canceled)
          end

          boleta_factura = BoletaFactura.find_by_factura(@order['number'])
          if !boleta_factura['processed']
            boleta_factura.update(processed: true)
          end

          redirect_to order_path(@order)
        else
          redirect_to checkout_state_path(@order.state)
        end
      else @order.nil?
        #Order not passed through correctly
        flash[:error] = I18n.t(:order_missing)
        redirect_to checkout_path
      end
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

    def delete(uri, data={}, hmac=nil)
      uri = URI.parse(uri)
      http = Net::HTTP.new(uri.host, uri.port)

      request = Net::HTTP::Delete.new(uri.request_uri, initheader = {'Content-Type' => 'application/json'})
      request.set_form_data(data)
      if hmac
        request["Authorization"] = hmac
      end

      return http.request(request)
    end

    def dispatchBatch(amount, sku, precio, idOc, direccion)
      amount = amount.to_i
      while amount > 200
        response = getStock(ENV['almacen_despacho'], sku, 200)
        if response.kind_of? Net::HTTPSuccess
          originProductList = JSON.parse(response.body)
          originProductList.each do |product|
            despacharStock(product['_id'], direccion, precio, idOc)
          end
        end
        amount -= 200
      end

      response = getStock(ENV['almacen_despacho'], sku, amount)
      if response.kind_of? Net::HTTPSuccess
        originProductList = JSON.parse(response.body)
        originProductList.each do |product|
          despacharStock(product['_id'], direccion, precio, idOc)
        end
      end
    end

    def despacharStock(productoId, direccion, precio, oc)
      hmac = generateHash('DELETE'+ productoId.to_s + direccion.to_s + precio.to_s + oc.to_s)
      uri  = ENV['bodega_system_url'] + 'stock'
      data = {'productoId' => productoId, 'direccion' => direccion, 'precio' => precio, 'oc' => oc}
      return delete(uri,data=data, hmac= hmac)
    end

    def getStock(almacenId, sku, limit=nil)
      hmac = generateHash('GET' +  almacenId.to_s + sku.to_s)
      if limit.nil?
        uri = ENV['bodega_system_url'] + 'stock?almacenId=' + almacenId.to_s + '&sku=' + sku.to_s
      else
        uri = ENV['bodega_system_url'] + 'stock?almacenId=' + almacenId.to_s + '&sku=' + sku.to_s + '&limit=' + limit.to_s
      end

      return get(uri, hmac= hmac)
    end

    def formatAddress(address)
      return address['address1'] + "\n" + address['address2'] + "\n" + address['city'] + " " + address['zipcode']
    end
  end
end
