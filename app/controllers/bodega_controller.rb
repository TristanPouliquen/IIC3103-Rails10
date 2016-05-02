class BodegaController < ApplicationController
  def getAlmacenes
    return get(ENV['bodega_system_url'] + 'almacenes', hmac = generateHash('GET'))
  end

end