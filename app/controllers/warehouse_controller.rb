class WarehouseController < ApplicationController

  def is_authenticated?(parameters)
    if !request.headers.env.has_key?('HTTP_AUTHORIZATION')
      return false
    else
      data = ''
      parameters.each do |param|
        data += param
      end
      secret = ENV["clave_bodega"]
      hmac = OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha1'), secret.encode("ASCII"), data.encode("ASCII"))
      signature = Base64.encode64(hmac).chomp
      theoretical_header = 'INTEGRACION grupo10:' + signature

      return theoretical_header == request.headers.env['HTTP_AUTHORIZATION']
    end
  end

  def getWarehouses
    if is_authenticated?(['GET'])
      warehouses = Almacen.all
      render json: warehouses, root: false
    else
      render json: {'msg' => 'Authentication failed'}, status: :unauthorized
    end
  end

  def getSkusWithStock
    if is_authenticated?(['GET', params[:id]])
      warehouse = Almacen.find(params[:id])
      count = {}
      warehouse.productos.each do |product|
        if count[product.sku]
          count[product.sku] += 1
        else
          count[product.sku] = 1
        end
      end
      @result = []
      count.keys.each do |sku|
        @result << {"_id" => sku, "total" => count[sku]}
      end
      render json: @result, root: false
    else
      render json: {'msg' => 'Authentication failed'}, status: :unauthorized
    end
  end

  def getStock
    if is_authenticated?(['GET', params[:almacenId], params[:sku]])
      if params.has_key?(:limit)
        if params[:limit] > 200
          limit = 200
        else
          limit = params[:limit]
        end
      else
        limit = 100
      end

      @results = Producto
        .where('almacen_id' => params[:almacenId], 'sku' => params[:sku])
        .limit(limit)

      render json: @results, root: false
    else
      render json: {'msg' => 'Authentication failed'}, status: :unauthorized
    end
  end

  def moverStock
    if is_authenticated?(['POST', params[:productoId], params[:almacenId]])
      almacen = Almacen.find(params[:almacenId])
      producto = Producto.find(params[:productoId])

      if almacen.has_space?
        producto.update_attributes(almacen)
        response = producto
      else
        response = "No hay espacio en el almacen de destino"
        status = :bad_request
      end

      render json: response, status: status
    else
      render json: {'msg' => 'Authentication failed'}, status: :unauthorized
    end
  end

  def moverStockBodega
    if is_authenticated?(['POST', params[:productoId], params[:almacenId]])
      almacen = Almacen.find(params[:almacenId])
      producto = Producto.find(params[:productoId])   
      #a completar
    else
      render json: {'msg' => 'Authentication failed'}, status: :unauthorized
    end
  end

  def despacharStock
    if is_authenticated?(['DELETE', params[:productoId], params[:direccion], params[:precio], params[:ocId]])
      producto = Producto.find(params[:productoId])    
      #a completar
    else
      render json: {'msg' => 'Authentication failed'}, status: :unauthorized
    end
  end

  def producirStock
    if is_authenticated?(['PUT', params[:sku], params[:cantidad], params[:trxId]])
      sku = Producto.find(params[:sku])    
      #a completar
    else
      render json: {'msg' => 'Authentication failed'}, status: :unauthorized
    end
  end

  def getCuentaFabrica
    if is_authenticated?(['GET'])
      @cuentaFabrica = 00123400000000 #Nose cual es el número nuestro, inventé cualquiera :S
      render json: @cuentaFabrica, root: false
    else
      render json: {'msg' => 'Authentication failed'}, status: :unauthorized
    end
  end
end
