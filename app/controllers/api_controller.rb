require 'net/http'

class ApiController < ApplicationController
  def getAccount
    response = get(ENV['general_system_url'] + 'banco/cuenta/' + ENV['id_cuenta_banco'])

    render json: response.body    
  end

  def getStockWithSku
    almacen = Almacen.where('despacho' => true)
    stock = Producto
      .where('almacen_id' => almacen.id, 'sku' => params[:sku])
      .length

    @result = { 'sku' => params[:sku], 'stock' => stock}

    render json: @result, root: false
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
      render json: {'aceptado' => false, 'idfactura' => params[:idfactura]}
    else
      payBill(params[:idfatura])
      render json: {'aceptado' => true, 'idfactura' => params[:idfactura]}
    end
  end

  def receivePayment
    result = processPayment(params[:idtrx])

    #TODO : Dispatch the products
  end

# Functions to process the data and decide to accept or reject
  def processPurchaseOrder(idOc)
    # TODO : Logic to accept or reject purchase order
    return {'accepted' => true, 'message' => ''}
  end

  def processBill(idBill)
    # TODO : Logic to accept or reject bill
    return {'accepted' => true, 'message' => ''}
  end

  def processPayment(idTransaction)
    # TODO : Logic to accept or reject payment
    return {'accepted' => true, 'message' => ''}
  end


# functions to access the API of the general system
  def getPurchaseOrder(idOc)
    response = get(ENV["general_system_url"] + "oc/obtener/" + idOc.to_s)

    return response
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

  def rejectPurchaseOrder(idOc, data)
    # Call mare.ing.puc.cl/oc/rechazar/idOc

    response = post(ENV["general_system_url"] + 'oc/rechazar/' + idOc.to_s, data)

    return response
  end
  
  def createBill(idOc)
    # Call mare.ing.puc.cl/facturas
    response = put(ENV["general_system_url"] + "facturas")

    # TODO : recuperate bill ID (idBill) and group number of origin (groupNumber)
    post("http://integra" + groupNumber.to_s + ".ing.puc.cl/api/facturas/recibir/" + idBill.to_s)

    return response
  end

  def getBill(idBill)
    response = get(ENV["general_system_url"] + "facturas/" + idBill.to_s)

    return response
  end
  
  def payBill(idBill)
    bill = getBill(idBill)
    data = {'monto' => bill.valor_total, 'origen' => ENV['id_cuenta_banco']}
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

  def checkPayment(idTransaction)
    # Call mare.ing.puc.cl/banco/trx/idTransaction
    response = get(ENV['general_system_url'] + 'banco/trx/' + idTransaction.to_s)

    return response
  end
  
  
end
