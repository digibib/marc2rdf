#!/usr/bin/env ruby 
# encoding: UTF-8
$stdout.sync = true

require 'rubygems'
require 'bundler/setup'
require 'grape'
require "json"

# RDFmodeler loads all other classes in marc2rdf
require_relative './lib/rdfmodeler.rb'

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

# custom option validator :length
class Length < Grape::Validations::SingleOptionValidator
  def validate_param!(attr_name, params)
    unless params[attr_name].length >= @option
      throw :error, :status => 400, :message => "#{attr_name}: must be at the most #{@option} characters long"
    end
  end
end

class API < Grape::API
  helpers do
    def logger
      logger = API.logger #Logger.new(File.expand_path("../logs/#{ENV['RACK_ENV']}.log", __FILE__))
    end
  end
  
  prefix 'api'
  format :json
  default_format :json
  use ApiErrorHandler
  
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
    
  resource :library do
    desc "all libraries"
    get "/" do
      { :libraries => Library.new.all }
    end
    
    desc "get library by id"
    get "/:id" do
      content_type 'json'
      logger.info params
      
      library = Library.new.find_by_id(params[:id])
        throw :error, :status => 404,
              :message => "No library with id: " +
                          "#{params[:id]}" unless library
        { :library => library }
    end
 
    desc "get specific library mapping"
    get ":id/mapping" do
      library = Library.new.find_by_id(params[:id])
      if library
        { :mapping => library.mapping }
      else
        logger.error "library mapping not found"   
        error!("library mapping not found", 400)
      end
    end

    desc "save specific library mapping"
      params do
        requires :mapping, desc: "Mapping file"
      end
    put ":id/mapping" do
      content_type 'json'
      logger.info "PUT: params: #{params}"
      library = Library.new.find_by_id(params[:id])
      library.mapping = params[:mapping]
      Library.new.save(library)
      logger.info "PUT: params: #{params} - updated mapping: #{library.mapping}"
      { :mapping => library.mapping }
    end
            
    desc "create new library"
      params do
        requires :name,       type: String, length: 5, desc: "Name of library"
        optional :config,     desc: "Config file"
        optional :mapping,    desc: "Mapping file"
        optional :oai,        desc: "OAI settings"
        optional :harvesting, type: String, desc: "Harvesting settings file" 
      end
    post "/" do
      content_type 'json'
      library = Library.new.create(params)
      Library.new.save(library)
      logger.info "POST: params: #{params} - created library: #{library}"
      { :library => library }
    end

    desc "edit/update library"
      params do
        requires :id,         type: Integer, desc: "ID of library"
        optional :name,       type: String,  length: 5, desc: "Name of library"
        optional :config,     desc: "Config file"
        optional :mapping,    desc: "Mapping file"
        optional :oai,        desc: "OAI settings"
        optional :harvesting, type: String,  desc: "Harvesting settings file" 
      end
    put "/" do
      content_type 'json'
      valid_params = ['id','name','config','mapping','oai','harvesting']
      # do we have a valid parameter?
      if valid_params.any? {|p| params.has_key?(p) }
        # delete params not listed in valid_params
        logger.info "params before: #{params}"
        params.delete_if {|p| !valid_params.include?(p) }
        logger.info "params after: #{params}"
        
        before  = Library.new.find_by_id(params[:id])
        after   = Library.new.update(params)
        Library.new.save(after)
        logger.info "updated library: #{after}"
        { :before => before, :after => after }
      else
        logger.error "invalid or missing params"   
        error!("Need at least one param of id|name|config|mapping|oai|harvesting", 400)      
      end
    end
    
    desc "delete a library"
      params do
        requires :id, type: Integer, desc: "ID of library"
      end
    delete "/" do
      content_type 'json'
      library = Library.new.find_by_id(params[:id])
      Library.new.delete(params[:id])
      logger.info "DELETE: params: #{params} - deleted library: #{library}"
      { :library => library }
    end
  end # end library namespace
  
  resource :mapping do
    desc "return mapping template"
    get "/" do
      mapping = JSON.parse(IO.read(File.join(File.dirname(__FILE__), 'db/templates', 'mapping_skeleton.json')))
      { :mapping => mapping }
    end
  end # end mapping namespace
end
