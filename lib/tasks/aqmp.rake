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
        puts payload
      end
    rescue Bunny::NotFound => _
      puts "Ofertas queue not found"
    ensure
      b.close if b.open?
    end
  end

end
