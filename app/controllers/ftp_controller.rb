require 'net/ftp'
class FtpController < ApplicationController
  def index
    # ftp = Net::FTP.new
    # ftp.connect("mare.ing.puc.cl",22)
    # ftp.login("ENV['usuario_ftp']","ENV['clave_ftp']")
    # files=ftp.chdir("/pedidos")
    # files=ftp.nlst("*.txt")
    # ftp.getbinaryfile('nif.rb-0.91.gz', 'nif.gz', 1024)

    # Net::FTP.open('mare.ing.puc.cl', ENV['usuario_ftp'], ENV['clave_ftp']) do |ftp|

    # ftp.chdir('/pedidos')
    # files = ftp.list
    # puts "list out of directory:"
    # puts files
  end
end
