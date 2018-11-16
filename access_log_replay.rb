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
options.ssl = false

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

  opts.on("-d", "--delay N", "Wait N seconds between requests.") do |n|
    options.delay = n.to_i
  end

end

opt_parser.parse!(ARGV)

if options.host.nil?
  options.host = options.server.split(":").first
end

protocol = "http"

File.foreach(options.filename).with_index do |line,line_number|
  puts "Processing line #{line_number}" if line_number % 1000 == 0
  # Parse the line and extract method, HTTP Code, params, etc.
  fields = line.split
  method = fields[5]
  path_and_params = fields[6]
  return_code = fields[8]

  # skip if it's not a GET
  next unless method.include? "GET"

  # Build URI
  begin
    uri = URI(protocol + "://" + options.server + path_and_params)
  rescue
    puts "!! Skipping request on line number #{line_number}. Bad URI."
    puts "!! Offending URI: #{path_and_params}"
    next
  end
  
  # Send the request
  req = Net::HTTP::Get.new(uri, 'Host' => options.host)

  begin
    if options.ssl
      response = https(uri).request(req)
    else
      response = Net::HTTP.start(uri.hostname, uri.port) do |http|
        http.request(req)
      end
    end
  rescue
    puts "!! Skipping request on line number #{line_number}. Error in sending HTTP request. Previous request(s) might have cause a server error."
    next
  end

  puts "Request on line #{line_number} matches" unless /flag/.match(response.body).nil?
  if response.code != return_code
    puts "!! Request on line number #{line_number} has a different HTTP return code."
    puts "!! Received #{response.code}, but log has #{return_code}"
    puts "!! Request was #{path_and_params}"
  end
  sleep(options.delay)
end

def https(uri)
  Net::HTTP.new(uri.host, uri.port).tap do |http|
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end
end
