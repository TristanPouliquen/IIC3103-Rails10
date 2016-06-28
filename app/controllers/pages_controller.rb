require 'json'
class PagesController < BodegaController
  def index
  end

  def businessIntelligence
    # Saldo diario
    saldo_diarios = SaldoDiario.all.pluck(:saldo, :date)
    @saldo_diarios = []
    saldo_diarios.each do |item|
      item = {'date' => item[1].strftime("%F"), "value" => item[0]}
      @saldo_diarios << item
    end

    # Facturacion diaria
    @fac = getDailyTransaction
  end

  def dayTransactions
    date = Time.strptime(params[:date], "%Y-%m-%d").in_time_zone("Santiago")
    date_1 = date + 1.day

    render json: getTransactions(date.to_i * 1000, date_1.to_i * 1000)
  end

  def home
    ordenesId = OrdenCompra.all.order(created_at: :desc)
    @ordenes = {'creada' => [], 'aceptada' => [], 'rechazada' => [], 'finalizada' => [], 'anulada' => []}
    ordenesId.each do |ordenC|
      orden = JSON.parse(get(ENV['general_system_url'] + 'oc/obtener/' + ordenC['idOC']).body)[0]
      if orden.nil?
        OrdenCompra.where(idOC: ordenC['idOC']).destroy_all
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

  def getTransactions(fechaInicio, fechaFin)
    uri = ENV['general_system_url'] + 'banco/cartola'
    data = {'id' => ENV['id_cuenta_banco'], 'fechaInicio' =>  fechaInicio, 'fechaFin' => fechaFin}

    response = JSON.parse(post(uri, data=data).body)
    return response
  rescue JSON::ParserError
    return { 'data' => [], 'total' => 0}
  end

  def getDailyTransaction
    volume = []
    amount = []

    date = Time.at(1466740800) # starting on 24-06-2016 at 00:00:00

    while date < Time.now()
      date_1 = date + 1.day

      orden_compras_ftp = OrdenCompra.where(proveedor: ENV['id_grupo'], canal: "ftp", created_at: date..date_1).pluck(:idOc)
      orden_compras_b2b = OrdenCompra.where(proveedor: ENV['id_grupo'], canal: "b2b", created_at: date..date_1).pluck(:idOc)
      factura_b2b = Factura.where(idOc: orden_compras_b2b)
      factura_ftp = Factura.where(idOc: orden_compras_ftp)
      boleta_volume = BoletaFactura.where(created_at: date..date_1).count
      boleta_amount = BoletaFactura.where(created_at: date..date_1).sum('monto')

      volume << {'day' => date.strftime("%d/%m/%Y"), 'ftp' => factura_ftp.count, 'b2b' => factura_b2b.count, 'b2c' => boleta_volume}
      amount << {'day' => date.strftime("%d/%m/%Y"), 'ftp' => factura_ftp.sum('monto'), 'b2b' => factura_b2b.sum('monto'), 'b2c' => boleta_amount}

      date = date_1
    end

    return {'volume' => volume, 'amount' => amount}
  end
end
