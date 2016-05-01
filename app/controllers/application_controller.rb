class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  def get(uri)
    uri = URI.parse(uri)
    http = Net::HTTP.new(uri.host, uri.port)

    request = Net::HTTP::Get.new(uri.request_uri)
    request["Content-Type"] = "application/json"

    return http.request(request)
  end

  def post(uri,data = {})
    uri = URI.parse(uri)
    http = Net::HTTP.new(uri.port, uri.host)

    request = Net::HTTP::Post.new(uri.request_uri)
    request["Content-Type"] = "application/json"

    request.set_form_data(data)

    return http.request(request)
  end

  def put(uri, data={})
    uri = URI.parse(uri)
    http = Net::HTTP.new(uri.port, uri.host)

    request = Net::HTTP::Put.new(uri.request_uri)
    request["Content-Type"] = "application/json"

    request.set_form_data(data)

    return http.request(request)
  end

  def delete(uri)
    uri = URI.parse(uri)
    http = Net.HTTP(uri.port, uri.host)

    request = New::HTTP::Delete.new(uri.request_uri)
    request["Content-Type"] = "application/json"

    return http.request(request)
  end

end
