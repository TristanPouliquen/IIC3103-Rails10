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
      if product['_id'].to_i == sku.to_i
        @result['stock'] = product['total']
      end
    end

    return result
  end

  def receivePurchaseOrder
    result = processPurchaseOrder(params[:idoc])

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
        render json: {'aceptado' => true, 'idoc' => params[:idoc]}
      else
        render json: {'error' => 'Error validando la orden:' + response.body.to_s}, status: :internal_server_error
      end
    end
  end

  def receiveBill
    result = processBill(params[:idfactura])

    if !result['accepted']
      response = rejectBill(params[:idfactura])
      if response.kind_of? Net::HTTPSuccess
        render json: {'error' => result['message']}, status: result['status']
      else
        render json: {'error' => 'Error rechazando la factura'}, status: :internal_server_error
      end
    else
      response = payBill(params[:idfatura])
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
      # TODO : Dispatch  the products
      render json: {'validado' => true, 'idtrx' => params[:idtrx]}
    end
  end

# Functions to process the data and decide to accept or reject
  def processPurchaseOrder(idOc)
    # Hash with sku => unitPrice
    productPriceHash = {
      3 => 1468,
      9 => 1397,
      29 => 1868,
      35 => 1435,
      41 => 1407,
      54 => 2190
    }
    purchaseOrder = getPurchaseOrder(idOc)

    if purchaseOrder.nil? or purchaseOrder.empty?
      return {'accepted' => false, 'message' => 'Orden de compra no encontrada', 'status' => :not_found}
    else
      record = OrdenCompra.find_by_idOC idOc.to_s
      if !record.nil?
        return {'accepted' => false, 'message' => 'Orden de compra ya procesada', 'status' => :bad_request}
      else
        OrdenCompra.create idOC: idOc.to_s

        stock = retrieveStockWithSku(purchaseOrder['sku'])['stock']

        if purchaseOrder['cantidad'] > stock
          return {'accepted' => false, 'message' => 'No suficiente stock'}
        elsif purchaseOrder['precioUnitario'] >= productPriceHash[purchaseOrder['sku'].to_i]
          return {'accepted' => false, 'message' => 'Precio unitario demasiado bajo'}
        else
          return {'accepted' => true}
        end
      end
    end
  end

  def processBill(idBill)
    bill = getBill(idBill)

    if bill.nil? or bill.empty?
      return {'accepted' => false, 'message' => 'Factura no encontrada', 'status' => :not_found}
    else
      Factura.create idFactura: idBill.to_s

      purchaseOrder = getPurchaseOrder(bill['oc'])

      if bill['total'] != purchaseOrder['cantidad'] * purchaseOrder['precioUnitario']
        return {'accepted' => false, 'message' => 'Valor de la factura incoherente', 'status' => :bad_request}
      elsif bill['proveedor'] != ENV['id_grupo']
        return {'accepted' => false, 'message' => 'Error de proveedor', 'status' => :bad_request}
      end
    end

    response = payBill(idBill)
    if response.kind_of? Net::HTTPSuccess
      return {'accepted' => true}
    else
      return {'accepted' => false, 'message' => 'Error pagando la factura', 'status' => :internal_server_error}
    end
  end

  def processPayment(idTransaction, idFactura)
      transaction = getPayment(idTransaction)
      factura = getFactura(idFactura)

      if transaction.nil? or factura.nil? or transaction.empty? or factura.empty?
        return {'accepted' => false, 'message' => 'Transaccion o factura no encontrada', 'status' => :not_found}
      end
      if transaction['monto'] < factura['total']
        return {'accepted' => false, 'message' => 'Monto de la transaccion incoherente', 'status' => :bad_request}
      end
      if factura['proveedor'] != transaction['origen']
        return {'accepted' => false, 'message' => 'Proveedor y origen incoherentes', 'status' => :bad_request}
      end
      if transaction['destino'] != ENV['id_cuenta_banco']
        return {'accepted' => false, 'message' => 'Destino differente de nosotros', 'status' => :bad_request}
      end

      return {'accepted' => true}
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
    response = put(ENV["general_system_url"] + "facturas", data= {"oc" => idOc})

    bill = JSON.parse(response.body)[0]
    idBill = bill['id']

    groupNumber = groupIdHash[bill['cliente']]

    groupIdHash = {
      '571262b8a980ba030058ab4f' => 1,
      '571262b8a980ba030058ab50' => 2,
      '571262b8a980ba030058ab51' => 3,
      '571262b8a980ba030058ab52' => 4,
      '571262b8a980ba030058ab53' => 5,
      '571262b8a980ba030058ab54' => 6,
      '571262b8a980ba030058ab55' => 7,
      '571262b8a980ba030058ab56' => 8,
      '571262b8a980ba030058ab57' => 9,
      '571262b8a980ba030058ab58' => 10,
      '571262b8a980ba030058ab59' => 11,
      '571262b8a980ba030058ab5a' => 12
    }

    get("http://integra" + groupNumber.to_s + ".ing.puc.cl/api/facturas/recibir/" + idBill.to_s)

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
    groupIdToAccountId = {
      '571262b8a980ba030058ab4f' => '571262c3a980ba030058ab5b',
      '571262b8a980ba030058ab50' => '571262c3a980ba030058ab5c',
      '571262b8a980ba030058ab51' => '571262c3a980ba030058ab5d',
      '571262b8a980ba030058ab52' => '571262c3a980ba030058ab5f',
      '571262b8a980ba030058ab53' => '571262c3a980ba030058ab61',
      '571262b8a980ba030058ab54' => '571262c3a980ba030058ab62',
      '571262b8a980ba030058ab55' => '571262c3a980ba030058ab60',
      '571262b8a980ba030058ab56' => '571262c3a980ba030058ab5e',
      '571262b8a980ba030058ab57' => '',
      '571262b8a980ba030058ab58' => '571262c3a980ba030058ab63',
      '571262b8a980ba030058ab59' => '571262c3a980ba030058ab64',
      '571262b8a980ba030058ab5a' => '571262c3a980ba030068ab65'
    }
    bill = getBill(idBill)
    data = {'monto' => bill['total'], 'origen' => ENV['id_cuenta_banco'], 'destino' => groupIdToAccountId[bill['proveedor']]}
    # Call mare.ing.puc.cl/banco/trx with amount and account id in POST parameters
    response = post(ENV["general_system_url"] + "banco/trx", data)

    if response.kind_of? Net::HTTPSuccess
      body = JSON.parse(response.body)
      group_response = markBillAsPayed(idBill, body['_id'])
    end

    return group_response
  end

  def markBillAsPayed(idBill, idTrx)
    response = post(ENV['general_system_url'] + 'facturas/pay', {'id' => idBill})

    groupIdHash = {
      '571262b8a980ba030058ab4f' => 1,
      '571262b8a980ba030058ab50' => 2,
      '571262b8a980ba030058ab51' => 3,
      '571262b8a980ba030058ab52' => 4,
      '571262b8a980ba030058ab53' => 5,
      '571262b8a980ba030058ab54' => 6,
      '571262b8a980ba030058ab55' => 7,
      '571262b8a980ba030058ab56' => 8,
      '571262b8a980ba030058ab57' => 9,
      '571262b8a980ba030058ab58' => 10,
      '571262b8a980ba030058ab59' => 11,
      '571262b8a980ba030058ab5a' => 12
    }

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
end
