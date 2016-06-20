require 'net/http'
require 'json'
require "erb"
include ERB::Util

class SpreeController < Spree::BaseController

  def postFB(msg,link="")
    graph = Koala::Facebook::API.new(ENV['page_access_token'])
    return graph.put_connections('me', 'feed', {:message => msg, :link => link})
  end

  def postTW(msg, link="")
    client = Twitter::REST::Client.new do |config|
      config.consumer_key        = ENV['twitter_consumer_key']
      config.consumer_secret     = ENV['twitter_consumer_secret']
      config.access_token        = ENV['twitter_access_token']
      config.access_token_secret = ENV['twitter_access_token_secret']
    end
    tweet = msg + " " + URI.encode(link)
    response = client.update(tweet)
    return response
  end

  def success
    boleta_factura = BoletaFactura.find_by_factura(params[:factura])
    order = Spree::Order.find_by_number(params[:factura])
    order.update(state: 'complete', completed_at: Time.now)
    address = Spree::Address.find(order['ship_address_id'])
    address_string = formatAddress(address)

    if !boleta_factura['processed']
      boleta_factura.update(processed: true)
      order.line_items.each do |item|
        variant = Spree::Variant.find(item['variant_id'])
        if variant.nil?
          next
        else
          sku = variant['sku']
          quantity = item['quantity']
          price = item['price']

          Thread.new do
            stock_item = Spree::StockItem.find_by_variant_id(variant['id'])
            stock_item.adjust_count_on_hand(-quantity)
            stock_item.save
            dispatchBatch(quantity, sku, price.to_i, boleta_factura[:boleta], address_string)
          end
        end
      end
    end
    @boleta = getBoleta(boleta_factura[:boleta])[0]
    flash[:success] = "Your order #{params[:factura]} was correctly processed"
  end

  def failure
    boleta_factura = BoletaFactura.find_by_factura(params[:factura])
    order = Spree::Order.find_by_number(params[:factura])
    order.update(state: 'canceled',completed_at: Time.now)
    @boleta = getBoleta(boleta_factura[:boleta])[0]
    flash[:error] = "Your order #{params[:factura]} did not terminate correctly"
  end

  def spreePay
    result = []

    order = Spree::Order.incomplete.find_by_state_lock_version(params[:order][:state_lock_version])

    boleta_creation = put(ENV['general_system_url'] + 'facturas/boleta', data = {'proveedor' => ENV['id_grupo'], 'cliente' => order['email'], 'total' => order['item_total'].to_i})

    if boleta_creation.kind_of? Net::HTTPSuccess
      BoletaFactura.create(factura: order['number'], boleta: JSON.parse(boleta_creation.body)['_id'])
      callbackURL = url_encode(ENV['group_system_url'] + 'spree/order/' + order['number'] + '/success').to_s
      cancelURL = url_encode(ENV['group_system_url'] + 'spree/order/' + order['number'] + '/failure').to_s
      url = ENV['payment_system_url'] + 'pagoenlinea?callbackUrl='+ callbackURL + '&cancelUrl='+ cancelURL + '&boletaId=' + JSON.parse(boleta_creation.body)['_id']
      redirect_to url
    else
      flash[:error] = "An error occured in the process of your order: " + boleta_creation.body
      redirect_to '/spree/checkout/delivery'
    end
  end

  private
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
