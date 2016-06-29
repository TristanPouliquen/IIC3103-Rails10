require "bunny"
require 'json'
require 'koala'
require 'twitter'

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
        #   'sku' =>"3",
        #   "precio" => 1000,
        #   "inicio" => Time.now.to_i * 1000,
        #   "fin" => (Time.now + 60*60*24).to_i*1000,
        #   "codigo" => "test",
        #   "publicar" => true
        # }
        variant = Spree::Variant.find_by_sku(msg['sku'])
        if !variant.nil?
          price = Spree::Price.find_by_variant_id(variant['id'])
          product = Spree::Product.find(variant['product_id'])
          promotion = Spree::Promotion.create!(
            name: product['name'],
            description: product['name'] + ' a ' + msg['precio'].to_s,
            starts_at: Time.at(msg['inicio'].to_i / 1000),
            expires_at: Time.at(msg['fin'].to_i / 1000)
            )
          if !msg['codigo'].empty?
            promotion.update!(code: msg['codigo'])
          end
          promotion_rule = Spree::PromotionRule.create!(
            type: "Spree::Promotion::Rules::Product",
            promotion: promotion
            )
          promotion_rule.update_attributes({
            'product_ids_string' => product['id'].to_s,
            'preferred_match_policy' => 'any'
            })
          calculator = Spree::Calculator::PercentPerItem.create(
            preferred_percent: (price['amount'] - msg['precio']) / price['amount'] * 100
            )
          promotion_action = Spree::Promotion::Actions::CreateItemAdjustments.create(
            promotion: promotion,
            calculator: calculator
            )

          if msg['publicar']
            productURL = ENV['group_system_url'] + "spree/products/" + product['slug']
            msgFB = "Nueva promocion!\nDisfruta de " + product['name'] + " al precio increible de " + msg['precio'].to_s + " CLP "
            msgFB = msgFB + "del " + Time.at(msg['inicio']).to_time.strftime("%d/%m") + " hasta el " + Time.at(msg['fin']).to_time.strftime("%d/%m") + "!\n"
            msgFB = msgFB + "Cliquea el enlace y utiliza el codigo " + msg['codigo'] + "!"
            msgTW = "#Promocion!\n" + product['name'] + " a " + msg["precio"].to_s + " CLP "
            msgTW = msgTW + "de " + Time.at(msg['inicio']).to_time.strftime("%d/%m") + " hasta" + Time.at(msg['fin']).to_time.strftime("%d/%m") + "!\n"
            msgTW = msgTW + "Codigo " + msg['codigo']
            puts 'Posting to FB and Twitter'
            postFB(msgFB, productURL)
            postTW(msgTW, productURL)
          end
        end
      end
    rescue Bunny::NotFound => _
      puts "Ofertas queue not found"
    ensure
      b.close if b.open?
    end
    puts "Finished processing queue"
  end
end

def postFB(msg,link="")
  graph = Koala::Facebook::API.new(ENV['page_access_token'])
  return graph.put_connections('me', 'feed', {:message => msg, :link => link})
end

def postTW(msg, link="")
  client = Twitter::REST::Client.new do |config|
    config.consumer_key        = ENV['twitter_consumer_key']
    config.consumer_secret     = ENV['twitter_consumer_secret']
    config.access_token        = ENV['twitter_access_token']
    config.access_token_secret = ENV['twitter_access_token_secret']
  end
  tweet = msg + " " + URI.encode(link)
  response = client.update(tweet)
  return response
end
