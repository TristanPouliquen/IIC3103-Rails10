class BodegaController < ApplicationController
  def getAlmacenes
    return get(ENV['bodega_system_url'] + 'almacenes', hmac = generateHash('GET'))
  end

  def getSkusWithStock(almacenId)
    hmac = generateHash('GET' + almacenId.to_s)
    uri = ENV['bodega_system_url'] + 'skusWithStock?almacenId=' + almacenId.to_s

    return get(uri, hmac= hmac)
  end

end