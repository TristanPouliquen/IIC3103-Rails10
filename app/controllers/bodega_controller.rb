class BodegaController < ApplicationController

  def move
    originWarehouseId = params[:origin]
    destinationWarehouseId = params[:destination]
    amount = params[:amount].to_i
    Thread.new do
      moveBatch(amount,params[:sku], originWarehouseId, destinationWarehouseId)
    end

    flash[:info] = "Movimiento de los productos en procesamiento. Puede demorar unos minutos."
    redirect_to '/bodega/admin/index'
  end

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

    return get(uri, hmac= hmac)
  end

  def moverStock(productoId, almacenId)
    hmac = generateHash('POST' + productoId.to_s + almacenId.to_s)
    uri = ENV['bodega_system_url'] + 'moveStock'
    data= {"productoId"=>productoId, "almacenId"=>almacenId}

    return post(uri, data= data , hmac= hmac )
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

  def moverStockBodega(productoId, almacenId, oc, precio)
    hmac = generateHash('POST' + productoId.to_s + almacenId.to_s)
    uri = ENV['bodega_system_url'] + 'moveStockBodega'
    data= {"productoId"=>productoId, "almacenId"=>almacenId, "oc"=>oc, "precio"=> precio}

    return post(uri, data= data, hmac= hmac)
  end

  def moveBatchBodega(amount, sku, precio, idOc, destinationId)
    amount = amount
    while amount > 200
      moveBatchFromAlmacen(sku, 200, destinationId, idOc, precio)
      amount = amount -200
    end

    moveBatchFromAlmacen(sku, amount, destinationId, idOc, precio)
  end

  def moveBatchFromAlmacen(sku, amount, destinationId, idOc, precio)
    responseX = getSkusWithStock(ENV['almacen_X'])
    stockX = JSON.parse(responseX.body)
    responseY = getSkusWithStock(ENV['almacen_Y'])
    stockY = JSON.parse(responseY.body)
    if stockX.has_key?(sku)&&stockX['sku']>amount
      moveProducts(ENV['almacen_X'] , sku, amount, ENV['almacen_despacho'], idOc, precio)
    else
      stock_X = stockX.has_key?(sku) ? stockX['sku']:0;
      moveProducts(ENV['almacen_X'] , sku, stock_X, ENV['almacen_despacho'], idOc, precio)
      moveProducts(ENV['almacen_Y'] , sku, amount-stock_X, ENV['almacen_despacho'], idOc, precio)
      end
    end
    moveProducts(ENV['almacen_despacho'] , sku, amount, destinationId, idOc, precio)
  end

  def moveProducts(originId, sku, amount, destinationId, idOc, precio)
    response = getStock(originId, sku, amount)
    if response.kind_of? Net::HTTPSuccess
      originProductList = JSON.parse(response.body)
      originProductList.each do |product|
        moverStockBodega(product['_id'], destinationId , idOc, precio)
      end
    end
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
