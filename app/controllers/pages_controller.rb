require 'json'

class PagesController < BodegaController
  def home
    ordenesId = OrdenCompra.all.order(created_at: :desc)
    @ordenes = {'creada' => [], 'aceptada' => [], 'rechazada' => [], 'finalizada' => [], 'anulada' => []}
    ordenesId.each do |orden|
      orden = JSON.parse(get(ENV['general_system_url'] + 'oc/obtener/' + orden['idOC']).body)[0]
      if orden.nil?
        OrdenCompra.where(idOC: orden['idOC']).destroy_all
      else
        @ordenes[orden['estado']] << orden
      end
    end
  end

  def warehouses
    almacenes = getAlmacenes
    @almacen = {}
    almacenes.each do |almacen|
      if almacen["recepcion"]
        @almacen['recepcion'] = almacen
      elsif almacen["despacho"]
        @almacen['despacho'] = almacen
      elsif almacen["pulmon"]
        @almacen['pulmon'] = almacen
      end
    end

    @almacen['recepcion']['porcentaje'] = ((@almacen['recepcion']["usedSpace"].to_f / @almacen['recepcion']["totalSpace"].to_f) * 100).round(2)
    @almacen['despacho']['porcentaje'] = ((@almacen['despacho']["usedSpace"].to_f / @almacen['despacho']["totalSpace"].to_f) * 100).round(2)
    @almacen['pulmon']['porcentaje'] = ((@almacen['pulmon']["usedSpace"].to_f / @almacen['pulmon']["totalSpace"].to_f) * 100).round(2)

    @stock = getStockPorAlmacen
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
