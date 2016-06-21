require "bunny"

namespace :aqmp do
  desc "TODO"
  task consume: :environment do
    b = Bunny.new ENV["cloud_aqmp_url"]
    b.start
    begin
      ch = b.create_channel
      q = ch.queue("ofertas", :passive => true)
      puts Time.now.in_time_zone('Santiago').to_s + ' : Processing promotions queue messages'
      while q.message_count > 0
        delivery_info, properties, payload = q.pop
        msg = JSON.parse(payload)
        # Test message
        # msg = {
        #   'sku' =>"APC-00001",
        #   "precio" => 10,
        #   "inicio" => Time.now.to_i * 1000,
        #   "fin" => (Time.now + 60*60*24).to_i*1000,
        #   "codigo" => "test",
        #   "publicar" => true
        # }
        variant = Spree::Variant.find_by_sku(msg['sku'])
        product = Spree::Product.find(variant['product_id'])
        promotion = Spree::Promotion.create!(
          name: product['name'],
          code: msg['codigo'],
          description: product['name'] + ' a ' + msg['precio'].to_s,
          usage_limit: 1000000,
          starts_at: Time.at(msg['inicio'].to_i / 1000),
          expires_at: Time.at(msg['fin'].to_i / 1000)
          )
        promotion_rule = Spree::PromotionRule.create!(
          type: "Spree::Promotion::Rules::Product",
          preferences: {'preferred_match_policy' => 'any'},
          promotion: promotion,
          product_ids_string: product['id'].to_s
          )
        calculator = Spree::Calculator::FlatRate.create(
          preferred_currency: 'USD',
          preferred_amount: msg['precio']
          )
        promotion_action = Spree::Promotion::Actions::CreateItemAdjustments.create(
          promotion: promotion,
          calculator: calculator
          )
      end
    rescue Bunny::NotFound => _
      puts "Ofertas queue not found"
    ensure
      b.close if b.open?
    end
  end

end
