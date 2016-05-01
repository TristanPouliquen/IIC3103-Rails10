class WarehouseController < ApplicationController
  def getWarehouses
    @warehouses = Almacen.all
    render json: @warehouses, root: false
  end

  def getSkusWithStock
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
  end

  def getStock
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
      .where('almacen_id' => params[:id], 'sku' => params[:sku])
      .limit(limit)

    render json: @results, root: false
  end

  def moverStock
    almacen = Almacen.find(params[:almacenId])
    producto = Producto.find(params[:productoId])
    if 
    if almacen.has_space?
      producto.update_attributes(almacen)
      response = producto
    else
      response = "No hay espacio en el almacen de destino"
      status = :bad_request
    end

    render json: response, status: status
  rescue ActiveRecord::RecordNotFound
    render json: "Falta de argumentos", status: :bad_request
  end

  def moverStockBodega
      almacen = Almacen.find(params[:almacenId])
      producto = Producto.find(params[:productoId])   
     #a completar
  end

  def despacharStock
     producto = Producto.find(params[:productoId])    
     #a completar
  end

  def producirStock
     sku = Producto.find(params[:sku])    
     #a completar
  end

  def getCuentaFabrica
      @cuentaFabrica = 00123400000000 #Nose cual es el número nuestro, inventé cualquiera :S
      render json: @cuentaFabrica, root: false
    end

end

  