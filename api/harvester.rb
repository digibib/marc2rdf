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
      
      desc "test a harvester by some string lookup"
        params do
          requires :id, type: String, desc: "ID of harvester"
          requires :teststring, type: String, desc: "String to send to external API"
        end
      get "/test" do
        content_type 'json'
          logger.info params
          harvester = Harvest.find(:id => params[:id])
          error!("No harvester rule with id: #{params[:id]}", 404) unless harvester
          url = harvester.url['prefix'] + params[:teststring].to_s + harvester.url['suffix']
          response = Net::HTTP.get_response URI.parse url
          results = []
          harvester.remote['predicates'].each do | predicate, opts |
            results << { predicate => BatchHarvest.parse_xml(response, :xpath => opts["xpath"], :regexp_strip => opts["regex_strip"], :namespaces => harvester.remote["namespaces"] ) }
          end
          { :harvester => harvester, :response => response.body, :results => results }        
      end
      
      desc "harvest single record directly to rdfstore"
        params do
          requires :id, type: String, desc: "ID of resource"
          requires :library, type: String, desc: "ID of library"
          requires :harvester, type: String, desc: "ID of harvester"
        end
      post "/harvest" do
        content_type 'json'
          logger.info params
          library = Library.find(:id => params[:library].to_i)
          harvester = Harvest.find(:id => params[:harvester])
          error!("No library with id: #{params[:library]}", 404) unless library
          error!("No harvester rule with id: #{params[:harvester]}", 404) unless harvester
          error!("Need a test string/ID!", 404) if params[:id].empty?
          # get id of resource
          uri = RDF::URI(library.config["resource"]["base"] + library.config["resource"]["prefix"] + "#{params[:id]}")
          solutions = SparqlUpdate.find_resource_by_subject(uri)
          # get local predicate
          teststring = solutions.filter(:p => RDF.module_eval("#{harvester.local['predicate']}"))
          error!("resource with id #{params[:id]} not found!", 404) unless teststring.count > 0
          statements = []
          url = harvester.url['prefix'] + teststring.first[:o].to_s + harvester.url['suffix']
          response = Net::HTTP.get_response URI.parse url
          results = []
          harvester.remote['predicates'].each do | predicate, opts |
            results = BatchHarvest.parse_xml(response, :xpath => opts["xpath"], :regexp_strip => opts["regex_strip"], :namespaces => harvester.remote["namespaces"] )
            unless results.empty?
              results.each do | result |
                statements << RDF::Statement.new(
                  uri, 
                  RDF.module_eval(predicate), 
                  RDF::URI(result)
                )
              end
            end
          end
          error!("No results!", 404) if statements.empty?
          sparqlresult = SparqlUpdate.insert_harvested_triples(statements)            
          
          { :statements => statements.inspect, :result => sparqlresult }
      end                
    end # end harvester namespace    
  end
end
