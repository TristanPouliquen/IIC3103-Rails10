require 'json'

class PagesController < ApplicationController
  def home
    ordenesId = OrdenCompra.all
    @ordenes = {'creada' => [], 'aceptada' => [], 'rechazada' => [], 'finalizada' => [], 'anulada' => []}
    ordenesId.each do |orden|
      orden = JSON.parse(get(ENV['general_system_url'] + 'oc/obtener/' + orden['idOc']).body)
      @ordenes[orden['estado']] << orden
    end
  end

  def warehouses
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

  def getAlmacenes
    return get(ENV['bodega_system_url'] + 'almacenes', hmac = generateHash('GET'))
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
end
