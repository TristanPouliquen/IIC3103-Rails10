require 'net/sftp'

namespace :ftp do
  desc "TODO"
  task process: :environment do
    puts 'Processing FTP files'
    app = ActionDispatch::Integration::Session.new(Rails.application)
    uri = URI.parse(ENV['general_system_url'])

    Net::SFTP.start(uri.host, ENV['usuario_ftp'], :password => ENV['clave_ftp']) do |sftp|
        sftp.dir.foreach('/pedidos') do |entry|
            processed_files = FtpFile.pluck(:name)
            name = entry.name
            # We do not process files already processed.
            if !processed_files.include? name and name =~ /(.*)\.xml$/
                FtpFile.create name: name
                file = sftp.download!('/pedidos/' + entry.name)
                oc_info = Hash.from_xml(file)['order']
                if  !records.include?(oc_info['id'])
                    app.get '/api/oc/recibir/' + oc_info['id']
                end
            end
        end
    end
    puts 'Processed new FTP files'
  end
end
