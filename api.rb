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

  namespace 'library/:id' do
    desc "get skeleton mapping"
    get "/" do
      { :mapping => Map.new('mapping.json') }
    end
    
    desc "return a certain mapping from library id"
    get "/mapping" do
      map = Map.new
      map.find_by_library(params[:id].to_s)
      unless map 
        logger.error "Invalid URI"
        error!("\"#{params[:uri]}\" is not a valid URI", 400)
      else
        { :mapping => map.mapping }
      end
    end

  end # end library namespace
end
