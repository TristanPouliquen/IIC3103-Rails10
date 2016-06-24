require 'net/http'
require 'json'

class ApiController < BodegaController
  def getAccount
    response = get(ENV['general_system_url'] + 'banco/cuenta/' + ENV['id_cuenta_banco'])

    render json: response.body, root: false
  end

  def getStockWithSku
    render json: retrieveStockWithSku(params[:sku]), root: false
  end

  def retrieveStockWithSku(sku)
    hmac = generateHash('GET' + ENV['almacen_despacho'])
    stock = JSON.parse(get(ENV['bodega_system_url'] + 'skusWithStock?almacenId=' + ENV['almacen_despacho'], hmac = hmac).body)
    result = {'sku' => sku.to_i, 'stock' => 0}

    stock.each do |product|
      if product['_id'].to_i == sku.to_i && product.has_key?('total')
        result['stock'] = product['total']
      end
    end
    return result
  end

  def receivePurchaseOrder
    result = processPurchaseOrder(params[:idoc])
    purchaseOrder = getPurchaseOrder(params[:idoc])

    if !result['accepted']
      response = rejectPurchaseOrder(params[:idoc], result['message'])
      if response.kind_of? Net::HTTPSuccess
        render json: {'aceptado' => false, 'idoc' => params[:idoc], 'msg' => result['message']}
      else
        render json: {'error' => 'Error rechazando la orden:' + response.body.to_s}, status: :internal_server_error
      end
    else
      response = validatePurchaseOrder(params[:idoc])
      if response.kind_of? Net::HTTPSuccess
        bill_response = createBill(params[:idoc])
        if 'ftp' == purchaseOrder['canal']
          bill = JSON.parse(bill_response.body)
          Thread.new do
            dispatchProducts(params[:idoc], bill['_id'],'ftp')
          end
        end
        render json: {'aceptado' => true, 'idoc' => params[:idoc]}
      else
        render json: {'error' => 'Error validando la orden:' + response.body.to_s}, status: :internal_server_error
      end
    end
  end

  def receiveBill
    result = processBill(params[:idfactura])

    if !result['accepted']
      response = rejectBill(params[:idfactura], result['message'])
      if response.kind_of? Net::HTTPSuccess
        render json: {'validado' => false, 'idfactura' => params[:idfactura], 'message' => result['message']}
      else
        render json: {'error' => 'Error rechazando la factura'}, status: :internal_server_error
      end
    else
      response = payBill(params[:idfactura])
      if response.kind_of? Net::HTTPSuccess
        render json: {'validado' => true, 'idfactura' => params[:idfactura]}
      else
        render json: {'error' => 'Error pagando la factura: ' + response.body.to_s}, status: :internal_server_error
      end
    end
  end

  def receivePayment
    result = processPayment(params[:idtrx], params[:idfactura])
    if !result['accepted']
      render json: {'error' => result['message']}, status: result['status']
    else
      bill = getBill(params[:idfactura])[0]
      purchaseOrder = getPurchaseOrder(bill['oc'])
      Thread.new do
        dispatchProducts(bill['oc'], params[:idfactura], purchaseOrder['canal'])
      end
      render json: {'validado' => true, 'idtrx' => params[:idtrx]}
    end
  end

# Functions to process the data and decide to accept or reject
  def processPurchaseOrder(idOc)
    # Hash with sku => unitPrice
    productPriceHash = {
      3 => 1805,
      9 => 1704,
      29 => 4865,
      35 => 3351,
      41 => 3148,
      54 => 6314
    }
    purchaseOrder = getPurchaseOrder(idOc)

    if purchaseOrder.nil? or purchaseOrder.empty?
      return {'accepted' => false, 'message' => 'Orden de compra no encontrada', 'status' => :not_found}
    else
      record = OrdenCompra.find_by_idOC idOc.to_s
      if !record.nil?
        return {'accepted' => false, 'message' => 'Orden de compra ya procesada', 'status' => :bad_request}
      else
        OrdenCompra.create idOC: idOc.to_s, :origen purchaseOrder['proveedor'], :destino purchaseOrder['cliente'], :monto (purchaseOrder['precioUnitario']* purchaseOrder['cantidad']), :canal purchaseOrder['canal'], :cantidad purchaseOrder['cantidad'], :cantidad_despachada purchaseOrder['cantidadDespachada'], :estado purchaseOrder['estado']

        stock = retrieveStockWithSku(purchaseOrder['sku'])['stock']

        if purchaseOrder['cantidad'] > stock
          return {'accepted' => false, 'message' => 'No suficiente stock'}
        elsif purchaseOrder['precioUnitario'] < productPriceHash[purchaseOrder['sku'].to_i]
          return {'accepted' => false, 'message' => 'Precio unitario demasiado bajo'}
        else
          return {'accepted' => true}
        end
      end
    end
  end

  def processBill(idBill)
    bill = getBill(idBill)[0]

    if bill.nil? or bill.empty?
      return {'accepted' => false, 'message' => 'Factura no encontrada', 'status' => :not_found}
    else
      purchaseOrder = getPurchaseOrder(bill['oc'])

      Factura.create idFactura: idBill.to_s, :origen purchaseOrder['proveedor'], :destino purchaseOrder['cliente'], :monto (purchaseOrder['cantidad'] * purchaseOrder['precioUnitario']), :estado purchaseOrder['estado']
      if bill['total'] != purchaseOrder['cantidad'] * purchaseOrder['precioUnitario']
        return {'accepted' => false, 'message' => 'Valor de la factura incoherente', 'status' => :bad_request}
      elsif bill['cliente'] != ENV['id_grupo']
        return {'accepted' => false, 'message' => 'Error de cliente', 'status' => :bad_request}
      end
    end
    return {'accepted' => true}
  end

  def processPayment(idTransaction, idBill)
      transaction = getPayment(idTransaction)[0]
      factura = getBill(idBill)[0]

      if transaction.nil? or factura.nil? or transaction.empty? or factura.empty?
        return {'accepted' => false, 'message' => 'Transaccion o factura no encontrada', 'status' => :not_found}
      end
      if transaction['monto'] < factura['total']
        return {'accepted' => false, 'message' => 'Monto de la transaccion incoherente', 'status' => :bad_request}
      end
      if transaction['destino'] != ENV['id_cuenta_banco']
        return {'accepted' => false, 'message' => 'Destino differente de nosotros', 'status' => :bad_request}
      end

      return {'accepted' => true}
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

# functions to access the API of the general system
  def getPurchaseOrder(idOc)
    response = get(ENV["general_system_url"] + "oc/obtener/" + idOc.to_s)

    purchaseOrder = JSON.parse(response.body)[0]
    return purchaseOrder
  rescue JSON::ParserError
    return {}
  end

  def cancelPurchaseOrder(idOc)
    response = delete(ENV["general_system_url"] + "oc/anular/" + idOc.to_s)

    return response
  end

  def validatePurchaseOrder(idOc)
    # Call mare.ing.puc.cl/oc/recepcionar/idOc
    response = post(ENV["general_system_url"] + "oc/recepcionar/" + idOc.to_s)

    return response
  end

  def rejectPurchaseOrder(idOc, message)
    # Call mare.ing.puc.cl/oc/rechazar/idOc

    response = post(ENV["general_system_url"] + 'oc/rechazar/' + idOc.to_s, {'rechazo' => message})

    return response
  end

  def createBill(idOc)
    # Call mare.ing.puc.cl/facturas
    response = put(ENV["general_system_url"] + "facturas/", data= {"oc" => idOc})

    bill = JSON.parse(response.body)
    idBill = bill['_id']

    groupIdHash = JSON.parse(ENV['groups_id_to_number'])

    if groupIdHash.has_key?(bill['cliente'])
      groupNumber = groupIdHash[bill['cliente']]
      get("http://integra" + groupNumber.to_s + ".ing.puc.cl/api/facturas/recibir/" + idBill.to_s)
    end

    return response
  end

  def getBill(idBill)
    response = get(ENV["general_system_url"] + "facturas/" + idBill.to_s)

    bill = JSON.parse(response.body)
    return bill
  rescue JSON::ParserError
    return {}
  end

  def rejectBill(idBill, message)
    response = post(ENV['general_system_url'] + 'facturas/reject', {'id' => idBill.to_s, 'motivo' => message})

    return response
  end

  def cancelBill(idBill, message)
    response post(ENV['general_system_url'] + 'facturas/cancel', {'id' => idBill.to_s, 'motivo' => message})

    return response
  end

  def payBill(idBill)
    groupIdToAccountId = JSON.parse(ENV['groups_id_to_bank'])

    bill = getBill(idBill)[0]
    data = {'monto' => bill['total'], 'origen' => ENV['id_cuenta_banco'], 'destino' => groupIdToAccountId[bill['proveedor']]}
    # Call mare.ing.puc.cl/banco/trx with amount and account id in POST parameters
    response = put(ENV["general_system_url"] + "banco/trx", data)

    if response.kind_of? Net::HTTPSuccess
      body = JSON.parse(response.body)
      group_response = markBillAsPayed(idBill, body['_id'], bill['proveedor'])
    end
    return group_response
  end

  def markBillAsPayed(idBill, idTrx, providerId)
    response = post(ENV['general_system_url'] + 'facturas/pay', {'id' => idBill})

    groupIdHash = JSON.parse(ENV['groups_id_to_number'])
    groupNumber = groupIdHash[providerId]

    get("http://integra" + groupNumber.to_s + ".ing.puc.cl/api/pagos/recibir/" + idTrx.to_s + "?idfactura=" + idBill.to_s)

    return response
  end

  def getPayment(idTransaction)
    # Call mare.ing.puc.cl/banco/trx/idTransaction
    response = get(ENV['general_system_url'] + 'banco/trx/' + idTransaction.to_s)

    transaction = JSON.parse(response.body)

    return transaction
  rescue JSON::ParserError
    return {}
  end

  def getDatos
    render json: {'idGrupo' => ENV['id_grupo'], 'idCuentaBanco' => ENV['id_cuenta_banco'], 'idAlmacenRecepcion' => ENV['almacen_recepcion']}
  end
end
