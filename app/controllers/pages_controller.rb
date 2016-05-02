require 'json'

class PagesController < ApplicationController
  def home
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

    @almacen_recepcion['porcentaje'] = (@almacen_recepcion["usedSpace"] / @almacen_recepcion["totalSpace"]) * 100
    @almacen_despacho['porcentaje'] = (@almacen_despacho["usedSpace"] / @almacen_despacho["totalSpace"]) * 100
    @almacen_pulmon['porcentaje'] = (@almacen_pulmon["usedSpace"] / @almacen_pulmon["totalSpace"]) * 100
  end

  def getAlmacenes
    return get(ENV['bodega_system_url'] + 'almacenes', hmac = generateHash('GET'))
  end
end
