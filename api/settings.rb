#!/usr/bin/env ruby 
#encoding: utf-8
module API
  class Settings < Grape::API
    ### settings namespace ###
    resource :settings do
  
      desc "save repository settings"
        params do
          requires :store,           type: String, desc: "RDF Store"
          requires :sparql_endpoint, type: String, desc: "URI to Sparql Endpoint"
          requires :sparul_endpoint, type: String, desc: "URI to Sparql Update Endpoint"
          requires :username,        type: String, desc: "Username for Sparql Update"
          requires :password,        type: String, desc: "Password for Sparql Update"
          requires :timeout,         type: Integer, desc: "Timeout for Sparql request"
        end
      post "/repository" do
        content_type 'json'
        valid_params = ['store','sparql_endpoint','sparul_endpoint','username','password','timeout']
        settings = params.to_hash.reject { |key,_| !valid_params.include? key }
        SETTINGS["repository"] = settings
        File.open(CONFIG_FILE, 'w') do |f|
          f.write(JSON.pretty_generate(JSON.parse(SETTINGS.to_json)))
        end
        logger.info "POST: params: #{params} - saved settings: #{settings}"
        REPO = RDF::Virtuoso::Repository.new(
              SETTINGS["repository"]["sparql_endpoint"],
              :update_uri => SETTINGS["repository"]["sparul_endpoint"],
              :username => SETTINGS["repository"]["username"],
              :password => SETTINGS["repository"]["password"],
              :auth_method => SETTINGS["repository"]["auth_method"],
              :timeout => SETTINGS["repository"]["timeout"] ? SETTINGS["repository"]["timeout"] : 5)
        logger.info "REPO reloaded: #{REPO.inspect}"
        { :settings => settings }
      end

      desc "save global settings"
        params do
          requires :default_graph,  type: String, desc: "Default graph used in global Rules"
          requires :default_prefix, type: String, desc: "Default prefix used in Mapping and Rules"
        end
      post "/global" do
        content_type 'json'
        valid_params = ['default_graph','default_prefix']
        settings = params.to_hash.reject { |key,_| !valid_params.include? key }
        SETTINGS["global"] = settings
        File.open(CONFIG_FILE, 'w') do |f|
          f.write(JSON.pretty_generate(JSON.parse(SETTINGS.to_json)))
        end
        logger.info "POST: params: #{params} - saved settings: #{settings}"
        { :settings => settings }
      end
                  
    end # end settings namespace    
  end
end
