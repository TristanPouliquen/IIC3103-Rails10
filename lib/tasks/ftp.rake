require 'net/sftp'

namespace :ftp do
  desc "TODO"
  task process: :environment do
    uri = URI.parse(ENV['general_system_url'])
    oc_list = {}
    records = OrdenCompra.pluck(:idOC)

    Net::SFTP.start(uri.host, ENV['usuario_ftp'], :password => ENV['clave_ftp']) do |sftp|
        sftp.dir.foreach('/pedidos') do |entry|
            if entry.name =~ /(.*)\.xml$/
                file = sftp.download!('/pedidos/' + entry.name)
                oc_info = Hash.from_xml(file)['order']
                if  !records.include?(oc_info['id'])
                    oc_list[entry.name] = processPurchaseOrder(oc_info['id'])['accepted']
                end
                # Move order to 'procesados' directory when processed. Not possible until the 'procesados' folder is created
                # sftp.rename('/pedidos/' + entry.name, '/procesados/' + entry.name)
            end
        end
    end
    puts oc_list
  end
end
