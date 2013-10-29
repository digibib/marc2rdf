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
  # custom option validators
  class Length < Grape::Validations::SingleOptionValidator
    def validate_param!(attr_name, params)
      unless params[attr_name].length >= @option
        throw :error, :status => 400, :message => "#{attr_name}: must be at least #{@option} characters long"
      end
    end
  end

  class Valid_json < Grape::Validations::SingleOptionValidator
    def validate_param!(attr_name, params)
      begin
        JSON.parse(params[attr_name]) 
      rescue JSON::ParserError
        throw :error, :status => 400, :message => "#{attr_name}: must be valid JSON"
      end
    end
  end
  
  class Root < Grape::API
    helpers do
      def logger
        logger = Logger.new(File.expand_path("../logs/#{ENV['RACK_ENV']}.log", __FILE__))
      end
    end

    # simply lock entire API with session key
    before do
      error!('Unauthorized', 401) unless env['HTTP_SECRET_SESSION_KEY'] == SECRET_SESSION_KEY
    end

    # load all external api libraries
    Dir[File.dirname(__FILE__) + '/api/*.rb'].each do |file|
      require file
    end    
   
    prefix 'api'
    format :json
    default_format :json
    content_type :xml, "text/xml"
    content_type :json, "application/json"
    content_type :jpeg, "image/jpeg"

    use ApiErrorHandler
    
    mount API::Settings
    mount API::Mappings
    mount API::Libraries
    mount API::Conversion
    mount API::Oai
    mount API::Scheduling
    mount API::Rules
    mount API::Harvester
    mount API::Vocabularies
      
    before do
      # Of course this makes the request.body unavailable afterwards.
      # You can just use a helper method to store it away for later if needed. 
      logger.info "#{env['REMOTE_ADDR']} #{env['HTTP_USER_AGENT']} #{env['REQUEST_METHOD']} #{env['REQUEST_PATH']} -- Request: #{request.body.read}"
    end
  
    # Rescue and log validation errors gracefully
    rescue_from Grape::Exceptions::Validation do |e|
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
