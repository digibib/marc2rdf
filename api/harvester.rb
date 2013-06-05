#!/usr/bin/env ruby 
#encoding: utf-8
module API
  class Harvester < Grape::API
    ### harvester namespace ###
    resource :harvester do
      desc "return all harvesting rules"
      get "/" do
        content_type 'json'
        unless params[:id]
          { :harvester => Harvest.all }
        else
          logger.info params
          harvester = Harvest.find(params)
          error!("No harvester rule with id: #{params[:id]}", 404) unless harvester
          { :harvester => harvester }        
        end        
      end  
  
      desc "create new harvester"
        params do
          requires :name,  type: String, desc: "Short Name of Harvester"
        end
      post "/" do
        content_type 'json'
        harvester = Harvest.new.create(params)
        harvester.protocol = "http" unless params[:protocol]
        harvester.save
        logger.info "POST: params: #{params} - created harvester: #{harvester}"
        { :harvester => harvester }
      end
      
      desc "edit/update harvester"
        params do
          requires :id,             type: String, desc: "ID of Harvester"
          optional :name,           type: String, desc: "Short Name of Harvester"
          optional :description,    type: String, length: 5, desc: "Description"
          optional :protocol,       type: String, desc: "http|sparql"
          optional :url,            type: Hash,   desc: "url hash, :prefix and :suffix"
          optional :params,         type: Hash,   desc: "optional params hash"
          optional :namespaces,     type: Hash,   desc: "optional namespaces hash"
          optional :predicates,     type: Hash,   desc: "predicates to harvest"
          optional :limits,         type: Hash,   desc: "limits of harvest, keys: max_limit, batch_limit, delay, retry_limit"
          optional :custom_headers, type: Hash,   desc: "custom headers needed for harvest" 
        end
      put "/" do
        content_type 'json'
        valid_params = ['id','name','description','protocol','url','params','namespaces','predicates','limits','custom_headers']
        # do we have a valid parameter?
        if valid_params.any? {|p| params.has_key?(p) }
          harvester = Harvest.find(:id => params[:id])
          harvester.update(params)
          logger.info "updated harvest: #{harvester}"
          { :harvester => harvester}
        else
          logger.error "invalid or missing params"   
          error!("Need at least one param of id|description|protocol|url|params|namespaces|predicates|limits|custom_headers", 400)      
        end
      end
      
      desc "delete a harvest"
        params do
          requires :id, type: String, desc: "ID of harvester"
        end
      delete "/" do
        content_type 'json'
        harvester = Harvest.find(:id => params[:id])
        harvester.delete
        logger.info "DELETE: params: #{params} - deleted harvester: #{harvester}"
        { :harvester => harvester }
      end        
    end # end harvester namespace    
  end
end
