class BodegaController < ApplicationController
  def getAlmacenes
    return get(ENV['bodega_system_url'] + 'almacenes', hmac = generateHash('GET'))
  end

  def getSkusWithStock(almacenId)
    hmac = generateHash('GET' + almacenId.to_s)
    uri = ENV['bodega_system_url'] + 'skusWithStock?almacenId=' + almacenId.to_s

    return get(uri, hmac= hmac)
  end

  def getStock(almacenId, sku, limit=nil)
  	hmac = generateHash('GET' +  almacenId.to_S + sku.to_S)
  	if limit.nil?
  		uri = ENV['bodega_system_url'] + 'stock?almacenId=' + almacenId.to_S + '&sku=' + sku.to_S
  	else 
	  	uri = ENV['bodega_system_url'] + 'stock?almacenId=' + almacenId.to_S + '&sku=' + sku.to_S + '&limit=' + limit.to_S
	end

  	return get(uri, hmac= hmac)
  end

  def moverStock(productoId, almacenId)
  	hmac = generateHash('POST' + productoId.to_S + almacenId.to_S)
  	uri = ENV['bodega_system_url'] + 'moveStock'
  	data= {"productoId"=>productoId, "almacenId"=>almacenId}

  	return post(uri, data= data , hmac= hmac )	
  end

  def moverStockBodega(productoId, almacenId, oc, precio)
  	hmac = generateHash('POST' + productoId.to_S + almacenId.to_S)
  	uri = ENV['bodega_system_url'] + 'moveStockBodega'
  	data= {"productoId"=>productoId, "almacenId"=>almacenId, "oc"=>oc, "precio"=> precio}

  	return post(uri, data= data, hmac= hmac)
  end

  def despacharStock(productoId, direccion, precio, oc)
  	hmac = generateHash('DELETE'+ productoId.to_S + direccion.to_S + precio.to_S + oc.to_S)
	uri  = ENV['bodega_system_url'] + 'stock?productoId=' + productoId.to_S + '&direccion=' + direccion.to_S + '&precio=' + precio.to_S + '&oc=' + oc.to_S

	return delete(uri, hmac= hmac)
  end

  def producirStock(sku, trxId, cantidad)
  	hmac = generateHash('PUT' + sku.to_S + trxId.to_S + cantidad.to_S)
  	uri = ENV['bodega_system_url'] + 'fabrica/fabricar'
  	data= {"sku"=>sku, "trxId"=>trxId, "cantidad"=>cantidad}

  	return put(uri, data= data, hmac= hmac)
  	
  end

  def getCuentaFabrica()
  	hmac = generateHash('GET')
  	uri = ENV['bodega_system_url'] + 'fabrica/getCuenta'

  	return get(uri, hmac= hmac)
  	
  end


end