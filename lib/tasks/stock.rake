require 'net/http'

namespace :stock do
  desc "TODO"
  task update: :environment do
    puts Time.now.in_time_zone('Santiago').to_s + ' : Updating stocks'

    tabla_stock = Spree::StockItem.find_by_sql("SELECT * FROM spree_stock_items a, spree_variants b WHERE a.id = b.id")
    #tabla_stock = Spree::StockItem.joins(:variant).select('spree_stock_items.count_on_hand, spree_variants.sku')

    tabla_stock.each do |item|
      sku = item['sku']
      uri = URI.parse(ENV['group_system_url'] + 'api/consultar/' + sku)
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Get.new(uri.request_uri)
      response = http.request(request)
      quantity = JSON.parse(response.body)['stock']
      item['count_on_hand'] = quantity
      item.save
      puts sku.to_s + ': ' + quantity.to_s
    end
  end
  desc "TODO"
  task emptyRecepcion: :environment do
    puts Time.now.in_time_zone("Santiago").to_s +': Emptying Recepcion'
    listSku = JSON.parse(getSkusWithStock(ENV['almacen_recepcion']).body)
    listSku.each do |item|
      almacenes = getAlmacenes
      almacenXLibre = 0
      almacenYLibre = 0
      almacenes.each do |almacen|
        if almacen['_id'] == ENV['almacen_X']
          almacenX = almacen
          almacenXLibre = almacenX['totalSpace']-almacenX['usedSpace']
        elsif almacen['_id'] == ENV['almacen_Y']
          almacenY = almacen
          almacenYLibre = almacenY['totalSpace']-almacenY['usedSpace']
        end
      end

      if almacenXLibre > item['total']
        moveBatch(item['total'], item['_id'],ENV['almacen_recepcion'], ENV['almacen_X'])
      else
        moveBatch(almacenXLibre, item['_id'],ENV['almacen_recepcion'], ENV['almacen_X'])
        moveBatch(item['total']-almacenXLibre, item['_id'],ENV['almacen_recepcion'], ENV['almacen_Y'])
      end
    end
    puts 'Emptied Recepcion'
  end
  desc "TODO"
  task emptyPulmon: :environment do
    puts Time.now.in_time_zone("Santiago").to_s +': Emptying Pulmon'
    listSku = JSON.parse(getSkusWithStock(ENV['almacen_pulmon']).body)
    listSku.each do |item|
      almacenes = getAlmacenes
      almacenXLibre = 0
      almacenYLibre = 0
      almacenes.each do |almacen|
        if almacen['_id'] == ENV['almacen_X']
          almacenX = almacen
          almacenXLibre = almacenX['totalSpace']-almacenX['usedSpace']
        elsif almacen['_id'] == ENV['almacen_Y']
          almacenY = almacen
          almacenYLibre = almacenY['totalSpace']-almacenY['usedSpace']
        end
      end

      if almacenXLibre > item['total']
        moveBatch(item['total'], item['_id'],ENV['almacen_pulmon'], ENV['almacen_X'])
      else
        moveBatch(almacenXLibre, item['_id'],ENV['almacen_pulmon'], ENV['almacen_X'])
        moveBatch(item['total']-almacenXLibre, item['_id'],ENV['almacen_pulmon'], ENV['almacen_Y'])
      end
    end
    puts 'Emptied Pulmon'
  end
end

//

 def getAlmacenes
    hmac= generateHash('GET')
    uri= ENV['bodega_system_url'] + 'almacenes'
    return JSON.parse(get(uri, hmac= hmac).body)
  rescue JSON::ParserError
    return {}
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

def getSkusWithStock(almacenId)
    hmac = generateHash('GET' + almacenId.to_s)
    uri = ENV['bodega_system_url'] + 'skusWithStock?almacenId=' + almacenId.to_s
    return get(uri, hmac= hmac)
  end

def moverStock(productoId, almacenId)
    hmac = generateHash('POST' + productoId.to_s + almacenId.to_s)
    uri = ENV['bodega_system_url'] + 'moveStock'
    data= {"productoId"=>productoId, "almacenId"=>almacenId}

    return post(uri, data= data , hmac= hmac )
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


def moveBatch(amount, sku,originId, destinationId)
    amount = amount
    while amount > 200
      response = getStock(originId, sku, 200)
      if response.kind_of? Net::HTTPSuccess
        originProductList = JSON.parse(response.body)
        originProductList.each do |product|
          moverStock(product['_id'], destinationId)
        end
      end
      amount -= 200
    end

    response = getStock(originId, sku, amount)
    if response.kind_of? Net::HTTPSuccess
      originProductList = JSON.parse(response.body)
      originProductList.each do |product|
        moverStock(product['_id'], destinationId)
      end
    end
  end
