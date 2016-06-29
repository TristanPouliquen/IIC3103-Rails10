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
          boleta = JSON.parse(boleta_creation.body)
          BoletaFactura.create(factura: order['number'], boleta: boleta['_id'], monto: boleta['total'], estado: boleta['estado'])
          boletaId = boleta['_id']
        else
          flash[:error] = "An error occured in the process of your order: " + boleta_creation.body
          redirect_to '/spree/checkout/payment' && return
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
      now = Time.now
      if @order
        puts @order
        @order.update(completed_at: now)
        if payment_made
          #Payment successfully processed
          @order.payments.clear
          payment = @order.payments.create
          payment.started_processing
          payment.amount = params[:amount] || @order.total
          payment.payment_method = gateway
          payment.complete
          @order.state = "complete"
          @order.payment_state = "paid"
          @order.shipment_state = "pending"
          @order.update(state: "complete", payment_state: "paid", shipment_state: "pending")

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
                dispatchBatch(quantity, sku, price.to_i, "000000000000000000000000", address_string)
                @order.update(shipment_state: "shipped")
              end
            end
          end
        else
          flash[:danger] = "Payment canceled"
          @order.update(state: "canceled", payment_state: "failed", shipment_state: "canceled", canceled_at: now)
        end

        if @order.completed? or @order.canceled?
          if @order.state == "complete"
            flash[:notice] = I18n.t(:order_processed_successfully)
          elsif @order.state == "canceled"
            flash[:danger] = I18n.t(:payment_canceled)
          end

          boleta_factura = BoletaFactura.find_by_factura(@order['number'])
          if !boleta_factura['processed']
            boleta_factura.update(processed: true)
          end

          @order.save
          redirect_to order_path(@order)
        else
          redirect_to checkout_state_path(@order.state)
        end
      else
        #Order not passed through correctly
        flash[:error] = I18n.t(:order_missing)
        redirect_to checkout_path
      end
    end

    def generateHash(data)

      secret = ENV["clave_bodega"]
      hmac = OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha1'), secret.encode("ASCII"), data.encode("ASCII"))
      signature = Base64.encode64(hmac).chomp
      theoretical_header = 'INTEGRACION grupo10:' + signature

      return theoretical_header
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

    def post(uri,data = {}, hmac=nil)
      uri = URI.parse(uri)
      http = Net::HTTP.new(uri.host, uri.port)

      request = Net::HTTP::Post.new(uri.request_uri, initheader = {'Content-Type' => 'application/json'})
      if hmac
        request["Authorization"] = hmac
      end

      request.set_form_data(data)

      return http.request(request)
    end

    def despacharStock(productoId, direccion, precio, oc)
        hmac = generateHash('DELETE'+ productoId.to_s + direccion.to_s + precio.to_s + oc.to_s)
        uri  = ENV['bodega_system_url'] + 'stock'
        data = {'productoId' => productoId, 'direccion' => direccion, 'precio' => precio, 'oc' => oc}
        return delete(uri,data=data, hmac= hmac)
      end

      def dispatchBatch(amount, sku, precio, idOc, direccion)
        amount = amount.to_i
        while amount > 200
          moveBatchFromAlmacenForSpree(amount, sku, precio, idOc, direccion)
          amount -= 200
        end
        moveBatchFromAlmacenForSpree(amount, sku, precio, idOc, direccion)
      end

      def moveBatchFromAlmacenForSpree(amount, sku, precio, idOc, direccion)
        stockX = getStockAlmacenes(ENV['almacen_X'])
        stockY = getStockAlmacenes(ENV['almacen_Y'])
        stock = 0
        stockX.each do |stockItem|
          if stockItem.has_key?('_id') && stockItem['_id'] == sku
            stock = stockItem['total']
          end
        end

        if stock>amount
          moveProducts(ENV['almacen_X'] , sku, amount, ENV['almacen_despacho'])
        else
          moveProducts(ENV['almacen_X'] , sku, stock, ENV['almacen_despacho'])
          moveProducts(ENV['almacen_Y'] , sku, amount-stock, ENV['almacen_despacho'])
        end
        moveProductsForSpree(ENV['almacen_despacho'] , sku, amount, direccion, idOc, precio)
      end

      def moveProductsForSpree(originId, sku, amount, direccion, idOc, precio)
        response = getStock(originId, sku, amount)
        if response.kind_of? Net::HTTPSuccess
          originProductList = JSON.parse(response.body)
          originProductList.each do |product|
            despacharStock(product['_id'], direccion, precio, idOc)
          end
        end
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
      return address['address1'] + " / " + address['address2'] + " / " + address['city'] + " " + address['zipcode']
    end


    def getStockAlmacenes(almacenId)
      response = getSkusWithStock(almacenId)
      stock = JSON.parse(response.body)
    end

    def getSkusWithStock(almacenId)
      hmac = generateHash('GET' + almacenId.to_s)
      uri = ENV['bodega_system_url'] + 'skusWithStock?almacenId=' + almacenId.to_s
      return get(uri, hmac= hmac)
    end

    def moveProducts(originId, sku, amount, destinationId)
      response = getStock(originId, sku, amount)
      if response.kind_of? Net::HTTPSuccess
        originProductList = JSON.parse(response.body)
        originProductList.each do |product|
          moverStock(product['_id'], destinationId)
        end
      end
    end

    def moverStock(productoId, almacenId)
      hmac = generateHash('POST' + productoId.to_s + almacenId.to_s)
      uri = ENV['bodega_system_url'] + 'moveStock'
      data= {"productoId"=>productoId, "almacenId"=>almacenId}

      return post(uri, data= data , hmac= hmac )
    end
  end
end
