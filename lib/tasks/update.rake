namespace :update do
  desc "TODO"
  task orden: :environment do
    puts Time.now.in_time_zone('Santiago').to_s + ' : Procesando update ordenes de compra'
    orden_compras = OrdenCompra.where(estado: ['creada', 'aceptada']).all
    orden_compras.each do |orden|
      orden_c = getPurchaseOrder(orden['idOc'])
      orden.update!(estado: orden_c['estado'], cantidad_despachada: orden_c['cantidadDespachada'])
    end
    puts "Update de ordenes finalizado"
  end

  desc "TODO"
  task factura: :environment do
    puts Time.now.in_time_zone('Santiago').to_s + ' : Procesando update de facturas'
    facturas = Factura.where(estado: ['pendiente','creada']).all
    facturas.each do |fac|
    bill =  getBill(fac['idFactura'])
    fac.update!(estado: bill['estado'])
    end
    puts "Update de facturas finalizado"
  end

  desc "TODO"
  task dispatch: :environment do
    puts Time.now.in_time_zone('Santiago').to_s + ' : Procesando despacho de productos no despachados'
    orden_compras = OrdenCompra.where(estado: 'aceptada', proveedor: ENV['id_grupo']).all
    orden_compras.each do |orden|
      if orden['cantidad'] > orden['cantidad_despachada']
        factura = Factura.where(idOc: orden['idOc'])
        dispatchProducts(orden['idOc'] , factura['idFactura'] , orden['canal'])
      end
    end
    puts "Despacho de Stock Finalizado"
  end

  desc "TODO"
  task procesamientoOc: :environment do
    puts Time.now.in_time_zone('Santiago').to_s + ' : Introduciendo oredenes de compras creadas y no procesadas'
    orden_compras = OrdenCompra.where(estado: 'creada', proveedor: ENV['id_grupo'])
    orden_compras.each do |orden|
      respuesta = get(ENV['group_system_url']+'api/oc/recibir/'+orden['idOc'])
      resp = JSON.parse(response.body)
      if resp['estado']
        orden.update!(estado: "aceptada")
      else
        orden.update!(estado: "rechazada")
      end
    end
    puts "Termino del procesamiento de oc no procesadas"
  end

end

def getPurchaseOrder(idOc)
    response = get(ENV["general_system_url"] + "oc/obtener/" + idOc.to_s)
    purchaseOrder = JSON.parse(response.body)[0]
    return purchaseOrder
  rescue JSON::ParserError
    return {}
end

def getBill(idBill)
    response = get(ENV["general_system_url"] + "facturas/" + idBill.to_s)

    bill = JSON.parse(response.body)
    return bill
  rescue JSON::ParserError
    return {}
  end

 def dispatchProducts(idOc, idBill, canal)
    purchaseOrder = getPurchaseOrder(idOc)
    groupsAlmacenIdHash = JSON.parse(ENV['groups_id_to_almacen'])
    groupsNumberHash = JSON.parse(ENV['groups_id_to_number'])
    amount = purchaseOrder['cantidad']
    sku = purchaseOrder['sku']
    unitPrice = purchaseOrder['precioUnitario']
    idOc = purchaseOrder['_id']

    if 'ftp' == canal
      dispatchBatch(amount, sku, unitPrice, idOc, 'Internacional')
    else
      almacenId = groupsAlmacenIdHash[purchaseOrder['cliente']]
      moveBatchBodega(amount, sku, unitPrice, idOc, almacenId)
      get('http://integra' + groupsNumberHash[purchaseOrder['cliente']].to_s + '.ing.puc.cl/api/despachos/recibir/' + idBill)
    end
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
    if stockX.has_key?(sku)&&stockX['sku']>amount
      moveProducts(ENV['almacen_X'] , sku, amount, ENV['almacen_despacho'], idOc, precio)
    else
      stock_X = stockX.has_key?(sku) ? stockX['sku']:0;
      moveProducts(ENV['almacen_X'] , sku, stock_X, ENV['almacen_despacho'], idOc, precio)
      moveProducts(ENV['almacen_Y'] , sku, amount-stock_X, ENV['almacen_despacho'], idOc, precio)
    end
    moveProductsForSpree(ENV['almacen_despacho'] , sku, amount, direccion, idOc, precio)
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

  def moverStockBodega(productoId, almacenId, oc, precio)
    hmac = generateHash('POST' + productoId.to_s + almacenId.to_s)
    uri = ENV['bodega_system_url'] + 'moveStockBodega'
    data= {"productoId"=>productoId, "almacenId"=>almacenId, "oc"=>oc, "precio"=> precio}

    return post(uri, data= data, hmac= hmac)
  end

  def getStockAlmacenes(almacenId)
    response = getSkusWithStock(alamacenId)
    stock = JSON.parse(responseY.body)
  end

  def getSkusWithStock(almacenId)
    hmac = generateHash('GET' + almacenId.to_s)
    uri = ENV['bodega_system_url'] + 'skusWithStock?almacenId=' + almacenId.to_s
    return get(uri, hmac= hmac)
  end

  def generateHash(data)

    secret = ENV["clave_bodega"]
    hmac = OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha1'), secret.encode("ASCII"), data.encode("ASCII"))
    signature = Base64.encode64(hmac).chomp
    theoretical_header = 'INTEGRACION grupo10:' + signature

    return theoretical_header
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
    stockX = getStockAlmacenes(ENV['almacen_X'])
    stockY = getStockAlmacenes(ENV['almacen_Y'])
    if stockX.has_key?(sku)&&stockX['sku']>amount
      moveProducts(ENV['almacen_X'] , sku, amount, ENV['almacen_despacho'], idOc, precio)
    else
      stock_X = stockX.has_key?(sku) ? stockX['sku']:0;
      moveProducts(ENV['almacen_X'] , sku, stock_X, ENV['almacen_despacho'], idOc, precio)
      moveProducts(ENV['almacen_Y'] , sku, amount-stock_X, ENV['almacen_despacho'], idOc, precio)
    end
    moveProducts(ENV['almacen_despacho'] , sku, amount, destinationId, idOc, precio)
  end

  def moveProductsForSpree(originId, sku, amount, direccion, idOc, precio)
    response = getStock(originId, sku, amount)
    if response.kind_of? Net::HTTPSuccess
      originProductList = JSON.parse(response.body)
      originProductList.each do |product|
        despacharStock(product['_id'], direccion, idOc, precio)
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

  def get(uri, hmac=nil)
    uri = URI.parse(uri)
    http = Net::HTTP.new(uri.host, uri.port)

    request = Net::HTTP::Get.new(uri.request_uri, initheader = {'Content-Type' => 'application/json'})
    if hmac
      request["Authorization"] = hmac
    end

    return http.request(request)
  end