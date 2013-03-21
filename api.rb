#!/usr/bin/env ruby 
#encoding: utf-8
$stdout.sync = true
require 'grape'

# trap all exceptions and fail gracefuly with a 500 and a proper message
class ApiErrorHandler < Grape::Middleware::Base
  def call!(env)
    @env = env
    begin
      @app.call(@env)
    rescue Exception => e
      throw :error, :message => e.message || options[:default_message], :status => 500
    end
  end  
end

require_relative "./config/init.rb"

# access scheduler through drb socket
unless ENV['RACK_ENV'] == 'test'
  DRb.start_service
  Scheduler = DRbObject.new_with_uri DRBSERVER
end

module API

class Root < Grape::API
  helpers do
    def logger
      logger = Logger.new(File.expand_path("../logs/#{ENV['RACK_ENV']}.log", __FILE__))
    end
  end
  
  prefix 'api'
  format :json
  default_format :json
  use ApiErrorHandler
  
  mount API::Mapping
  mount API::Library
  mount API::Convert
  mount API::Oai
  mount API::Scheduler
  mount API::Rules
    
  before do
    # Of course this makes the request.body unavailable afterwards.
    # You can just use a helper method to store it away for later if needed. 
    logger.info "#{env['REMOTE_ADDR']} #{env['HTTP_USER_AGENT']} #{env['REQUEST_METHOD']} #{env['REQUEST_PATH']} -- Request: #{request.body.read}"
  end

  # Rescue and log validation errors gracefully
  rescue_from Grape::Exceptions::ValidationError do |e|
    logger = Logger.new(File.expand_path("../logs/#{ENV['RACK_ENV']}.log", __FILE__))
    logger.error "#{e.message}"
    Rack::Response.new({
        'status' => e.status,
        'message' => e.message,
        #'param' => e.param,
    }.to_json, e.status) 
  end
    

end
end
