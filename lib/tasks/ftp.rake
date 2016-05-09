require 'net/sftp'
require 'net/http'

namespace :ftp do
  desc "TODO"
  task process: :environment do
    puts Time.now.in_time_zone('Santiago').to_s + ' : Processing FTP files'
    uri = URI.parse(ENV['general_system_url'])
    records = OrdenCompra.pluck(:idOC)
    uri_group = URI.parse(ENV['group_system_url'])
    http = Net::HTTP.new(uri.host,uri.port)
    Net::SFTP.start(uri.host, ENV['usuario_ftp'], :password => ENV['clave_ftp']) do |sftp|
        sftp.dir.foreach('/pedidos') do |entry|
            processed_files = FtpFile.pluck(:name)
            name = entry.name
            puts 'Process file named: ' + name
            # We do not process files already processed.
            if !processed_files.include? name and name =~ /(.*)\.xml$/
                FtpFile.create name: name
                file = sftp.download!('/pedidos/' + entry.name)
                oc_info = Hash.from_xml(file)['order']
                if  !records.include?(oc_info['id'])
                    response = http.get('/api/oc/recibir/internacional/' + oc_info['id'])
                    puts oc_info['id'] + ' : ' + response.code
                end
            end
        end
    end
    puts Time.now.in_time_zone('Santiago').to_s + ' : Processed new FTP files'
  end
end
