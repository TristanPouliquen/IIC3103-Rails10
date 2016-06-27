require 'bunny'

b = Bunny.new ENV["cloud_aqmp_url"]
b.start
begin
  ch = b.create_channel
  q = ch.queue("ofertas", :passive => true)
  puts Time.now.in_time_zone('Santiago').to_s + ' : Processing promotions queue messages'
  q.subscribe do |delivery_info, properties, payload|
    msg = JSON.parse(payload)
    puts msg
  end
rescue Bunny::NotFound => _
  puts "Ofertas queue not found"
ensure
  b.close if b.open?
end
puts "Finished processing queue"
