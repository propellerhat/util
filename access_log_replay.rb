#!/usr/bin/env ruby
require 'uri'
require 'net/http'
require 'json'
require 'openssl'
require 'pry'
require 'optparse'
require 'optparse/time'
require 'ostruct'
require 'pp'

# parse args
# file_name: Name of access.log file
# server: The IP or hostname.
# host: The Host HTTP header. If missing, default to using server arg.
options = OpenStruct.new
options.host = nil
options.delay = 0

opt_parser = OptionParser.new do |opts|
  opts.banner = "Usage: #{ARGV[0]} [options]"

  opts.on("-f", "--file FILENAME", "access.log formatted file.") do |filename|
    options.filename = filename
  end

  opts.on("-s", "--server SERVER",
          "Port can be specified after a colon if not default. www.abc.com:8080") do |server|
    options.server = server
  end

  opts.on("-h", "--host-header VALUE",
          "Host header value. Defaults to the value provided in SERVER.") do |host|
    options.host = host
  end

  opts.on("-s", "--ssl", "Use SSL.") do
    options.ssl = true
  end

  opts.on("-d", "--delay N", "Wait N seconds between requests.") do |n|
    options.delay = n.to_i
  end

end

if options.host.nil?
  options.host = options.server.split(":").first
end

protocol = "http"
protocol << "s" if options.ssl

File.foreach(options.filename).with_index do |line,line_number|
  # Parse the line and extract method, HTTP Code, params, etc.
  fields = line.split
  method = fields[??]
  path_and_params = fields[??]
  return_code = fields[??]

  # skip if it's not a GET
  next unless method.include? "GET"

  # Build URI
  uri = URI(protocol + "://" options.sever + path_and_params)
  
  # Send the request
  req = Net::HTTP::Get.new(uri, 'Host' => options.host)

  if options.ssl
    response = https(uri).request(req)
  else
    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(req)
    end
  end

  pp response
  sleep(options.delay)
end

def https(uri)
  Net::HTTP.new(uri.host, uri.port).tap do |http|
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end
end
