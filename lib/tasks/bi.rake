require 'http'
require 'json'
require 'date'

namespace :bi do
  desc "TODO"
  task saldo: :environment do
    account = getAccount
    saldo = account['saldo']
    date = getCurrentDayDate
    SaldoDiario.create!(saldo: saldo, date: date)
    puts date.to_s + ": " + saldo.to_s + " CLP"
  end

  desc "TODO"
  task stock: :environment do
    date = getCurrentDayDate
    stock_diario = StockDiario.create!(date: date)
    stock_diario.maiz = getStock(3)
    stock_diario.carne = getStock(9)
    stock_diario.tela_lana = getStock(29)
    stock_diario.tequila = getStock(35)
    stock_diario.suero_leche = getStock(41)
    stock_diario.hamburguesa = getStock(54)
    stock_diario.save
    puts date.to_s + ': ' + stock_diario.stock.to_s
  end
end

def get(uri, hmac=nil)
  uri = URI.parse(uri)
  http = Net::HTTP.new(uri.host, uri.port)

  request = Net::HTTP::Get.new(uri.request_uri, initheader = {'Content-Type' => 'application/json'})
  if hmac
    request["Authorization"] = hmac
  end

  return http.request(request)
end

def getStock(sku)
  stock = 0
  response = get(ENV['group_system_url'] + 'api/consultar' + sku.to_s)
  if response.kind_of? Net::HTTPSuccess
    stock = JSON.parse(response.body)['stock']
  end

  return stock
end

def getAccount
  return JSON.parse(get(ENV['general_system_url'] + 'banco/cuenta/' + ENV['id_cuenta_banco']).body)[0]
rescue JSON::ParserError
  return {}
end

def getCurrentDayDate
  return Time.now.to_date.in_time_zone
end
