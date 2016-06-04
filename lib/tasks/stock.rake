require 'net/http'

namespace :stock do
  desc "TODO"
  task update: :environment do

    tabla_stock = Spree::StockItem.find_by_sql("SELECT * FROM spree_stock_items a, spree_variants b WHERE a.id = b.id")

    tabla_stock.each do |item|
      sku = item['sku']
      uri = URI.parse(ENV['group_system_url'] + 'api/consultar/' + sku)
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Get.new(uri.request_uri)
      response = http.request(request)
      quantity = JSON.parse(response.body)['stock']
      item['count_on_hand'] = quantity
    end
  end
end
