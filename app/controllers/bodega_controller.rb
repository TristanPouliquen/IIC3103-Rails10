class BodegaController < ApplicationController
  def getAlmacenes
    hmac= generateHash('GET')
    uri= ENV['bodega_system_url'] + 'almacenes'
    return JSON.parse(get(uri, hmac= hmac).body)
  rescue JSON::ParserError
    return {}
  end

  def getSkusWithStock(almacenId)
    hmac = generateHash('GET' + almacenId.to_s)
    uri = ENV['bodega_system_url'] + 'skusWithStock?almacenId=' + almacenId.to_s

    return get(uri, hmac= hmac)
  end

  def getStock(almacenId, sku, limit=nil)
    hmac = generateHash('GET' +  almacenId.to_s + sku.to_s)
    if limit.nil?
      uri = ENV['bodega_system_url'] + 'stock?almacenId=' + almacenId.to_s + '&sku=' + sku.to_s
    else 
      uri = ENV['bodega_system_url'] + 'stock?almacenId=' + almacenId.to_s + '&sku=' + sku.to_s + '&limit=' + limit.to_s
    end

    return JSON.parse(get(uri, hmac= hmac).body)
  rescue JSON::ParserError
    return {}
  end

  def moverStock(productoId, almacenId)
    hmac = generateHash('POST' + productoId.to_s + almacenId.to_s)
    uri = ENV['bodega_system_url'] + 'moveStock'
    data= {"productoId"=>productoId, "almacenId"=>almacenId}

    return post(uri, data= data , hmac= hmac )  
  end

  def moverStockBodega(productoId, almacenId, oc, precio)
    hmac = generateHash('POST' + productoId.to_s + almacenId.to_s)
    uri = ENV['bodega_system_url'] + 'moveStockBodega'
    data= {"productoId"=>productoId, "almacenId"=>almacenId, "oc"=>oc, "precio"=> precio}

    return post(uri, data= data, hmac= hmac)
  end

  def despacharStock(productoId, direccion, precio, oc)
    hmac = generateHash('DELETE'+ productoId.to_s + direccion.to_s + precio.to_s + oc.to_s)
    uri  = ENV['bodega_system_url'] + 'stock?productoId=' + productoId.to_s + '&direccion=' + direccion.to_s + '&precio=' + precio.to_s + '&oc=' + oc.to_s

    return delete(uri, hmac= hmac)
  end

  def producirStock(sku, trxId, cantidad)
    hmac = generateHash('PUT' + sku.to_s + cantidad.to_s + trxId.to_s)
    uri = ENV['bodega_system_url'] + 'fabrica/fabricar'
    data= {"sku"=>sku.to_s, "trxId"=>trxId, "cantidad"=>cantidad.to_i}

    return put(uri, data= data, hmac= hmac)
  end

  def getCuentaFabrica()
    hmac = generateHash('GET')
    uri = ENV['bodega_system_url'] + 'fabrica/getCuenta'

    return get(uri, hmac= hmac)
  end
end
