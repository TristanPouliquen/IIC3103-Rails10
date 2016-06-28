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

def getAccount
  return JSON.parse(get(ENV['general_system_url'] + 'banco/cuenta/' + ENV['id_cuenta_banco']).body)[0]
rescue JSON::ParserError
  return {}
end

def getCurrentDayDate
  return Time.now.to_date.in_time_zone
end
