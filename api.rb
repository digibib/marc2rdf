#!/usr/bin/env ruby 
# encoding: UTF-8
$stdout.sync = true

require 'rubygems'
require 'bundler/setup'
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

class API < Grape::API
  helpers do
    def logger
      logger = Logger.new(File.expand_path("../logs/#{ENV['RACK_ENV']}.log", __FILE__))
    end
  end
  
  prefix 'api'
  format :json
  default_format :json

  resource :library do
    desc "get all libraries"
    get "/" do
      { :libraries => Library.new.all }
    end
    
    desc "get specific library config"
    get ":id" do
      { :library => Library.new.find_by_id(params[:id]) }
    end
    
    desc "create new library"
      params do
        requires :name,       type: String, desc: "Name of library"
        optional :config,     type: String, desc: "Config file"
        optional :mapping,    type: String, desc: "Mapping file"
        optional :oai,        type: String, desc: "OAI settings"
        optional :harvesting, type: String, desc: "Harvesting settings file" 
      end
    post "/" do
      content_type 'json'
      library = Library.new.create(params)
      Library.new.save(library)
      logger.info "POST: params: #{params} - created library: #{library}"
      { :library => library }
    end

    desc "edit library"
      params do
        requires :id,         type: Integer, desc: "ID of library"
        optional :name,       type: String,  desc: "Name of library"
        optional :config,     type: String,  desc: "Config file"
        optional :mapping,    type: String,  desc: "Mapping file"
        optional :oai,        type: String,  desc: "OAI settings"
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
        
    desc "return a certain mapping from library id"
    get "/mapping" do
      map = Map.new
      map.find_by_library(params[:id].to_s)
      unless map 
        logger.error "Invalid ID"
        error!("\"#{params[:id]}\" is not a valid ID", 400)
      else
        { :mapping => map.mapping }
      end
    end

  end # end library namespace
end
