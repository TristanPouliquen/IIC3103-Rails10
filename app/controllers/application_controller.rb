require 'net/http'
require 'json'

class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  def generateHash(data)

    secret = ENV["clave_bodega"]
    hmac = OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha1'), secret.encode("ASCII"), data.encode("ASCII"))
    signature = Base64.encode64(hmac).chomp
    theoretical_header = 'INTEGRACION grupo10:' + signature

    return theoretical_header
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

  def post(uri,data = {}, hmac=nil)
    uri = URI.parse(uri)
    http = Net::HTTP.new(uri.host, uri.port)

    request = Net::HTTP::Post.new(uri.request_uri, initheader = {'Content-Type' => 'application/json'})
    if hmac
      request["Authorization"] = hmac
    end

    request.set_form_data(data)

    return http.request(request)
  end

  def put(uri, data={}, hmac=nil)
    uri = URI.parse(uri)
    http = Net::HTTP.new(uri.host, uri.port)

    request = Net::HTTP::Put.new(uri.request_uri, initheader = {'Content-Type' => 'application/json'})
    if hmac
      request["Authorization"] = hmac
    end
    request.set_form_data(data)

    return http.request(request)
  end

  def delete(uri, hmac=nil)
    uri = URI.parse(uri)
    http = Net.HTTP(uri.host, uri.port)

    request = New::HTTP::Delete.new(uri.request_uri, initheader = {'Content-Type' => 'application/json'})
    if hmac
      request["Authorization"] = hmac
    end

    return http.request(request)
  end

end
