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
end
