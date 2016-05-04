require 'json'

class AdminController < BodegaController
  before_filter :authenticate

  def authenticate
    authenticate_or_request_with_http_basic('Administration') do |username, password|
      username == 'grupo10' && password == ENV['password_admin']
    end
  end     

  def index
    almacenes = getAlmacenes
    almacenes.each do |almacen|
      if almacen["recepcion"]
        @almacen_recepcion = almacen
      elsif almacen["despacho"]
        @almacen_despacho = almacen
      elsif almacen["pulmon"]
        @almacen_pulmon = almacen
      end
    end

    @almacen_recepcion['porcentaje'] = ((@almacen_recepcion["usedSpace"].to_f / @almacen_recepcion["totalSpace"].to_f) * 100).round(2)
    @almacen_despacho['porcentaje'] = ((@almacen_despacho["usedSpace"].to_f / @almacen_despacho["totalSpace"].to_f) * 100).round(2)
    @almacen_pulmon['porcentaje'] = ((@almacen_pulmon["usedSpace"].to_f / @almacen_pulmon["totalSpace"].to_f) * 100).round(2)

    @stock = getStockPorAlmacen
  end

  def production
    account = getAccount
    @saldo = account["saldo"]
    corn = {"sku" => 3, "name" => "Maiz", "unitPrice" => 1468, "lot" => 30, 'productionTime' => 3.532, "productionOK" => false}
    meat = {"sku" => 9, "name" => "Carne", "unitPrice" => 1397, "lot" => 620, 'productionTime' => 4.279, "productionOK" => false}
    cloth = {"sku" => 29, "name" => "Tela de lana", "unitPrice" => 1868, "lot" => 400, 'productionTime' => 1.961,
            'requires' => [
              {'sku' => 31,'amount' => 368}
              ], "productionOK" => false}
    tequila = {"sku" => 35, "name" => "Tequila", "unitPrice" => 1435, "lot" => 500, 'productionTime' => 1.160,
              'requires' => [
                {'sku' => 44,'amount' => 430}
                ], "productionOK" => false}
    whey = {"sku" => 41, "name" => "Suero de leche", "unitPrice" => 1407, "lot" => 200, 'productionTime' => 3.983,
            'requires' => [
              {'sku' => 7,'amount' => 2000}
            ], "productionOK" => false}
    burgers = {"sku" => 54, "name" => "Hamburguesas", "unitPrice" => 2190, "lot" => 1800, 'productionTime' => 4.012,
                "requires" =>[
                  {"sku" => 9,"amount" => 2154},
                  {"sku" => 26, "amount" => 153}
              ], "productionOK" => false}
    @products = processProductionRequirements([corn, meat, cloth, tequila, whey, burgers], @saldo)
  end

  def produce
    production_account = JSON.parse(getCuentaFabrica.body)['cuentaId']
    transaction = putTransaction(params[:amount], production_account)
    if transaction.kind_of? Net::HTTPSuccess
      response = producirStock(params[:sku], transaction['_id'], params[:lot])
      if response.kind_of? Net::HTTPSuccess
        flash[:success] = "Produccion pedida correctamente!"
      else
        flash[:error] = "Production no pedida. Error: " + response.body.to_s
      end
    else
      flash[:error] = "Error con la transaccion: " + transaction.body.to_s
    end

    redirect_to '/admin/produccion'
  end

  def purchases
    account = getAccount
    @saldo = account["saldo"]
    wool = {'sku' => 31, 'name' => 'Lana', 'unitPrice' => 1431, 'required' => 368, 'group' => 3,
     'stock' => getStockFromOtherGroup(31,3),}
    agave = {'sku' => 44, 'name' => 'Agave', 'unitPrice' => 1091, 'required' => 430, 'group' => 4,
     'stock' => getStockFromOtherGroup(44,4),}
    milk = {'sku' => 7, 'name' => 'Leche', 'unitPrice' => 941, 'required' => 2000, 'group' => 12,
     'stock' => getStockFromOtherGroup(7,12),}
    salt = {'sku' => 26, 'name' => 'Sal', 'unitPrice' => 753, 'required' => 153, 'group' => 6,
     'stock' => getStockFromOtherGroup(26,6),}

    @products = processBuyRequirements([wool, agave, milk, salt], @saldo)
  end

  def purchase
    purchaseOrder = putPurchaseOrder(params[:sku], params[:provider], params[:amount], params[:unitPrice])

    if !purchaseOrder.empty?
      response = sendPurchaseOrder(purchaseOrder['_id'], params[:provider])
      if response.has_key?('aceptado')
        OrdenCompra.create idOc: purchaseOrder['_id']
        if response['aceptado']
          flash[:success] = 'Orden de compra enviada y aceptada'
        else
          flash[:error] = 'Orden de compra rechazada'
        end
      else
        flash[:error] = "Error en el envio de la orden de compra : #{response.to_s}"
      end
    else
      flash[:error] = "Error en a creation de la orden de compra : #{response.to_s}"
    end

    redirect_to '/admin/compras'
  end

  def processProductionRequirements(products, saldo)
    productsInRecepcion = JSON.parse(getSkusWithStock(ENV['almacen_recepcion']).body)
    productStockHash = {}
    productsInRecepcion.each do |product|
      productStockHash[product['_id']] = product['total']
    end

    products.each do |product|
      productionCost = product["unitPrice"] * product["lot"]
      if !product.has_key?("requires")
        product["productionOK"] = productionCost < saldo ? true : false
      else
        sufficientIngredients = true
        product['requires'].each do |ingredient|
          if !sufficientIngredients
            break
          end
          if productStockHash.has_key?(ingredient["sku"])
            sufficientIngredients = ingredient["amount"] < productStockHash[ingredient["sku"]]
          else
            sufficientIngredients = false
          end
        end
        product["productionOK"] = (sufficientIngredients and productionCost < saldo) ? true : false
      end
    end
    return products
  end

  def processBuyRequirements(products, saldo)
    products.each do |product|
      if product['stock'] == nil
        product['stock'] = 0
      end
      product['buyOK'] = (product['stock'] >= product['required'] and saldo > product['required']*product['unitPrice'])
    end

    return products
  end

  def getStockRecepcion
    hmac = generateHash('GET' + ENV['almacen_recepcion'])
    return JSON.parse(get(ENV['bodega_system_url'] + 'skusWithStock?almacenId=' + ENV['almacen_recepcion'], hmac = hmac).body)
  rescue JSON::ParserError
    return {}
  end

  def getStockDespacho
    hmac = generateHash('GET' + ENV['almacen_despacho'])
    return JSON.parse(get(ENV['bodega_system_url'] + 'skusWithStock?almacenId=' + ENV['almacen_despacho'], hmac = hmac).body)
  rescue JSON::ParserError
    return {}
  end

  def getStockPulmon
    hmac = generateHash('GET' + ENV['almacen_pulmon'])
    return JSON.parse(get(ENV['bodega_system_url'] + 'skusWithStock?almacenId=' + ENV['almacen_pulmon'], hmac = hmac).body)
  rescue JSON::ParserError
    return {}
  end

  def getStockPorAlmacen
    return {'recepcion' => getStockRecepcion, 'despacho' => getStockDespacho, 'pulmon' => getStockPulmon}
  end

  def getAccount
    return JSON.parse(get(ENV['general_system_url'] + 'banco/cuenta/' + ENV['id_cuenta_banco']).body)[0]
  rescue JSON::ParserError
    return {}
  end

  def putTransaction(amount, destination)
    uri = ENV['general_system_url'] + 'banco/trx'
    data = {'monto' => amount.to_i, 'origen' => ENV['id_cuenta_banco'].to_s, 'destino' => destination.to_s}
    return put(uri, data= data)
  end

  def getStockFromOtherGroup(sku, groupNumber)
    uri = 'http://integra'+ groupNumber.to_s + '.ing.puc.cl/api/consultar/' + sku.to_s
    return JSON.parse(get(uri).body)['stock']
  rescue JSON::ParserError
    return 0
  end

  def putPurchaseOrder(sku, group, quantity, unitPrice)
    uri = ENV['general_system_url'] + 'oc/crear'

    data = {
      'canal' => 'b2b',
      'cantidad' => quantity.to_i,
      'sku' => sku.to_s,
      'cliente' => ENV['id_grupo'].to_s,
      'proveedor' => group.to_s,
      'precioUnitario' => unitPrice.to_i,
      'fechaEntrega' => (Time.now + 60*60*24).to_i*1000,
      'notas' => "notas"
    }

    return JSON.parse(put(uri, data).body)
  rescue JSON::ParserError
    return {}
  end

  def sendPurchaseOrder(ocId, group)
    uri = 'http://integra' + group + '.ing.puc.cl/api/oc/recibir/' + ocId.to_s
    response = get(uri)
    return JSON.parse(response.body)
  rescue JSON::ParserError
    return {'statusCode': response.code}
  end
end
