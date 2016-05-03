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

    if !result.accepted
      rejectPurchaseOrder(params[:idoc], result.message)

      render json: {'aceptado' => false, 'idoc' => params[:idoc]}
    else
      validatePurchaseOrder(params[:idoc])

      render json: {'aceptado' => true, 'idoc' => params[:idoc]}
    end
  end

  def receiveBill
    result = processBill(params[:idfactura])

    if !result.accepted
      render json: {'validado' => false, 'idfactura' => params[:idfactura]}
    else
      payBill(params[:idfatura])
      render json: {'validado' => true, 'idfactura' => params[:idfactura]}
    end
  end

  def receivePayment
    result = processPayment(params[:idtrx], params[:idfactura])

    if !result.accepted
      render json: {'validado' => false, 'idtrx' => params[:idtrx]}
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

    if !purchaseOrder.empty?
      OrdenCompra.create idOC: idOc.to_s

      stock = retrieveStockWithSku(purchaseOrder['sku'])

      if purchaseOrder['cantidad'] > stock
        return {'accepted' => false, 'message' => 'No suficiente stock'}
      elsif purchaseOrder['precioUnitario'] >= productPriceHash[purchaseOrder['sku'].to_i]
        return {'accepted' => false, 'message' => 'Precio unitario demasiado bajo'}
      end

      return {'accepted' => true}
    end
  end

  def processBill(idBill)
    bill = getBill(idBill)

    if !bill.empty?
      Factura.create idFactura: idBill.to_s

      purchaseOrder = getPurchaseOrder(bill['oc'])

      if bill['valor_total'] != purchaseOrder['cantidad'] * purchaseOrder['precioUnitario']
        return {'accepted' => false, 'message' => 'Valor de la factura incoherente'}
      elsif bill['proveedor'] != ENV['id_grupo']
        return {'accepted' => false, 'message' => 'Error de proveedor'}
      end
    else
      return {'accepted' => false, 'message' => 'Factura no encontrada'}
    end

    return {'accepted' => true}
  end

  def processPayment(idTransaction, idFactura)
      transaction = getPayment(idTransaction)
      factura = getFactura(idFactura)

      if !transaction.empty? and !factura.empty?
        if transaction['monto'] != factura['valor_total']
          return {'accepted' => false, 'message' => 'Monto de la transaccion incoherente'}
        end
      else
        return {'accepted' => false, 'message' => 'Transaccion o factura no encontrada'}
      end

      return {'accepted' => true, 'message' => ''}
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
    response = post(ENV["general_system_url"] + "oc/recepcionar", {'id' => idOc.to_s})

    return response
  end

  def rejectPurchaseOrder(idOc, message)
    # Call mare.ing.puc.cl/oc/rechazar/idOc

    response = post(ENV["general_system_url"] + 'oc/rechazar',  {'id'=> idOc.to_s, 'rechazo' => message})

    return response
  end
  
  def createBill(idOc)
    # Call mare.ing.puc.cl/facturas
    response = put(ENV["general_system_url"] + "facturas", data= {"oc" => idOc})

    bill = JSON.parse(response.body)[0]
    groupNumber = bill['cliente']
    idBill = bill['id']

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
  
  def payBill(idBill)
    bill = getBill(idBill)
    data = {'monto' => bill['total'], 'origen' => ENV['id_cuenta_banco']}
    # Call mare.ing.puc.cl/banco/trx with amount and account id in POST parameters
    response = post(ENV["general_system_url"] + "banco/trx", data)

    if response.status = 200
      markBillAsPayed(idBill)
    end

    return response
  end

  def markBillAsPayed(idBill)
    response = post(ENV['general_system_url'] + 'facturas/pay', {'id' => idBill})

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
