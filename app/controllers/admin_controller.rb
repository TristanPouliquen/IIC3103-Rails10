require 'json'

class AdminController < BodegaController
  before_filter :authenticate

  def authenticate
    authenticate_or_request_with_http_basic('Administration') do |username, password|
      username == 'grupo10' && password == ENV['password_admin']
    end
  end     

  def index
    response = getAlmacenes
    almacenes = JSON.parse(response.body)
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
    account = JSON.parse(getAccount.body)[0]
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
  end

  def purchase
  end

  def processProductionRequirements(products, saldo)
    productsInRecepcion = getSkusWithStock(ENV['almacen_recepcion'])
    products.each do |product|
      if !product.has_key?("requires")
        productionCost = product["unitPrice"] * product["lot"]
        product["productionOK"] = productionCost < saldo ? true : false
      else
        # TODO : for each element of product["requires"], verify if the stock of this product is greater than
        # the requirements and if we have the money to pay for production.
      end
    end
    return products
  end

  def getStockRecepcion
    hmac = generateHash('GET' + ENV['almacen_recepcion'])
    return JSON.parse(get(ENV['bodega_system_url'] + 'skusWithStock?almacenId=' + ENV['almacen_recepcion'], hmac = hmac).body)
  end

  def getStockPorAlmacen
    hmac = generateHash('GET' + ENV['almacen_recepcion'])
    stock_recepcion = JSON.parse(get(ENV['bodega_system_url'] + 'skusWithStock?almacenId=' + ENV['almacen_recepcion'], hmac = hmac).body)
    hmac = generateHash('GET' + ENV['almacen_despacho'])
    stock_despacho = JSON.parse(get(ENV['bodega_system_url'] + 'skusWithStock?almacenId=' + ENV['almacen_despacho'], hmac = hmac).body)
    hmac = generateHash('GET' + ENV['almacen_pulmon'])
    stock_pulmon = JSON.parse(get(ENV['bodega_system_url'] + 'skusWithStock?almacenId=' + ENV['almacen_pulmon'], hmac = hmac).body)

    return {'recepcion' => stock_recepcion, 'despacho' => stock_despacho, 'pulmon' => stock_pulmon}
  end

  def getAccount
    return get(ENV['general_system_url'] + 'banco/cuenta/' + ENV['id_cuenta_banco'])
  end
end
