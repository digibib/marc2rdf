#!/usr/bin/env ruby 
#encoding: utf-8
module API
  class Mappings < Grape::API
    ### mappings namespace ###
    resource :mappings do
      desc "return all mappings or specific mapping"
      get "/" do
        content_type 'json'
        unless params[:id]
          { :mappings => Mapping.new.all }
        else
          logger.info params
          mapping = Mapping.new.find(params)
          error!("No mapping with id: #{params[:id]}", 404) unless mapping
          { :mapping => mapping }        
        end        
      end  
      
      ### REMOVE WHEN DONE
      desc "return mapping template or id"
      get "/template" do
        content_type 'json'
        mapping = JSON.parse(IO.read(File.join(File.dirname(__FILE__), '../config/templates', 'mapping_skeleton.json')))
        { :mapping => mapping }
      end
    
      desc "create new mapping"
        params do
          requires :name,        type: String, desc: "Short Name of Mapping"
          requires :description, type: String, length: 5, desc: "Description"
          requires :mapping,     desc: "The actual Mapping"
        end
      post "/" do
        content_type 'json'
        mapping = Mapping.new.create(params)
        mapping.save
        logger.info "POST: params: #{params} - created mapping: #{mapping}"
        { :mapping => mapping }
      end
          
      desc "edit/update mapping"
        params do
          requires :id,          type: String, desc: "ID of Mapping"
          requires :mapping,     desc: "The actual Mapping"
          optional :name,        type: String, desc: "Short Name of Mapping"
          optional :description, type: String, length: 5, desc: "Description"
        end
      put "/" do
        content_type 'json'
        valid_params = ['id','name','description','mapping']
        # do we have a valid parameter?
        if valid_params.any? {|p| params.has_key?(p) }
          mapping = Mapping.new.find(:id => params[:id])
          mapping.update(params)
          logger.info "updated mapping: #{mapping}"
          { :mapping => mapping}
        else
          logger.error "invalid or missing params"   
          error!("Need at least one param of id|name|description|mapping", 400)      
        end
      end

      desc "delete a mapping"
        params do
          requires :id, type: String, desc: "ID of mapping"
        end
      delete "/" do
        content_type 'json'
        mapping = Mapping.new.find(:id => params[:id])
        mapping.delete
        logger.info "DELETE: params: #{params} - deleted mapping: #{mapping}"
        { :mapping => mapping }
      end        
                
    end # end mappings namespace
  end
end
