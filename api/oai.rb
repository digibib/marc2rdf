#!/usr/bin/env ruby 
#encoding: utf-8
module API
class Oai < Grape::API
  resource :oai do
    desc "validate a OAI repository, find sets and identifier"
      params do
        requires :id, type: Integer, desc: "ID of library"
      end
    get "/validate" do
      content_type 'json'
      library = Library.find(:id => params[:id].to_i)
      logger.info "library: #{library.oai}"
      oai = OAIClient.new(library.oai["url"], 
        :format => library.oai["format"], 
        :parser => library.oai["parser"], 
        :timeout => library.oai["timeout"],
        :redirects => library.oai["redirects"],
        :set => library.oai["set"])
      oai.validate
      return  { :result => "not validated!" } unless oai.identify_response
      { :repo => oai.identify_response, :id => oai.oai_id, :datasets => oai.available_sets }
    end 

    desc "get a record"
      params do
        requires :id,       type: Integer, desc: "ID of library"
        requires :record,   type: String, desc: "Record identifier" 
        optional :filename, type: String, desc: "Filename, for saving" 
      end
    put "/getrecord" do
      content_type 'json'
      library = Library.find(:id => params[:id].to_i)
      oai = OAIClient.new(library.oai["url"], 
        :format => library.oai["format"], 
        :parser => library.oai["parser"], 
        :timeout => library.oai["timeout"],
        :redirects => library.oai["redirects"])
      unless params[:record].empty?
        oai.get_record :identifier => params[:record], :metadata_prefix => library.oai["format"]
      else
        oai.get_record :metadata_prefix => library.oai["format"]
      end
      unless oai.records.is_a?(OAI::GetRecordResponse)
        error!("Invalid or non-existent resource ID: #{params[:record]}", 404) 
      end
      logger.info "GetRecord result: identifier #{params[:record]}\n #{oai.records.record.metadata.to_s}"
      xmlreader = MARC::XMLReader.new(StringIO.new(oai.records.record.metadata.to_s)) 
      logger.info "Marc response: #{xmlreader.inspect}"
      rdfrecords = []
      # create an appendable file if save activated
      file = File.open(File.join(File.dirname(__FILE__), '../db/converted/', "#{params[:filename]}"), 'a+') if params[:filename]
      xmlreader.each do |marc|
        rdf = RDFModeler.new(library.id, marc)
        rdf.set_type(library.config["resource"]["type"])        
        rdf.convert
        rdf.statements.each {|s| rdfrecords.push(s)}
      end
      file.write(RDFModeler.write_ntriples(rdfrecords)) if file
      file.close if file
      { :resource => rdfrecords }
    end 
            
    desc "harvest a record batch"
      params do
        requires :id,            type: Integer,  desc: "ID of library"
        optional :from,          type: String, desc: "From Date"
        optional :until,         type: String, desc: "To Date"
        optional :tags,          type: String,   desc: "Tags"
        optional :write_records, type: Boolean,  desc: "Write converted records to file"
        optional :sparql_update, type: Boolean,  desc: "Update Repository directly"
        optional :save_oairesponse, type: Boolean,  desc: "Dump oai response to file"
      end
    put "/harvest" do
      content_type 'json'
      # Schedule harvest with from/until optional params, default from yesterday
      logger.info "OAI harvest params: #{params}"
      result = Scheduler.start_oai_harvest(params)
      { :result => result }
    end 

    desc "harvest a full set to file"
      params do
        requires :id,            type: Integer,  desc: "ID of library"
        optional :tags,          type: String,   desc: "Tags"
      end
    put "/harvest_full" do
      content_type 'json'
      # Schedule full harvest of set
      params[:from] = "1970-01-01"
      params[:full] = true
      params[:tags] = "oaiharvest-full"
      params[:save_oairesponse] = true
      logger.info "OAI full harvest to file, params: #{params}"
      result = Scheduler.start_oai_harvest(params)
      { :result => result }
    end 

    # TODO: deprecated - /harvest_full will do both harvest and convert
    desc "convert a harvested full set from file"
      params do
        requires :id,            type: Integer,  desc: "ID of library"
        optional :tags,          type: String,   desc: "Tags"
        optional :write_records, type: Boolean,  desc: "Write converted records to file"
        optional :sparql_update, type: Boolean,  desc: "Update Repository directly"
      end
    put "/convert_full" do
      content_type 'json'
      # Schedule full harvest of set
      logger.info "OAI full conversion from file,  params: #{params}"
      result = Scheduler.convert_full_oai_set_from_file(params)
      { :result => result }
    end 

    desc "schedule an OAI harvest"
      params do
        requires :id,            type: Integer,  desc: "ID of library"
        optional :frequency,     type: String,   desc: "Frequency"
        optional :tags,          type: String,   desc: "Tags"
        optional :write_records, type: Boolean,  desc: "Write converted records to file"
        optional :sparql_update, type: Boolean,  desc: "Update Repository directly"
      end
    put "/schedule_harvest" do
      content_type 'json'
      # Schedule harvest with from/until optional params, default from yesterday
      #logger.info "OAI harvest params: #{params}"
      # first check if library is not already scheduled
      test = Scheduler.find_jobs_by_library(params[:id])
      puts test.inspect
      error!("Library already scheduled for harvest!", 400) unless test.empty?
      params[:tags] = "oaiharvest-full-convert"
      result = Scheduler.schedule_oai_harvest(params)
      error!("Missing schedule frequency in library or supplied params!", 400) unless result
      { :result => result }
    end 
    
    ## NEEDS FIXING ##
    desc "saves a record batch"
      params do
        requires :id,       type: Integer, desc: "ID of library"
        optional :from,     type: String, desc: "From Date"
        optional :until,    type: String, desc: "To Date"
        optional :filename, type: String, desc: "Filename, for saving" 
      end
    put "/save" do
      content_type 'json'
      library = Library.find(:id => params[:id].to_i)
      logger.info "library: #{library.oai}"
      oai = OAIClient.new(library.oai["url"], 
        :format => library.oai["format"], 
        :parser => library.oai["parser"], 
        :timeout => library.oai["timeout"],
        :redirects => library.oai["redirects"])
      oai.query(:from => params[:from], :until => params[:until])
      logger.info "oai response: #{oai.response}"
      file = File.open(File.join(File.dirname(__FILE__), '../db/converted/', "#{params[:filename]}"), 'a+') if params[:filename]
      oai.response.entries.each do |record| 
        unless record.deleted?
          xmlreader = MARC::XMLReader.new(StringIO.new(record.metadata.to_s)) 
          xmlreader.each do |marc|
            rdf = RDFModeler.new(library.id, marc)
            rdf.set_type(library.config["resource"]["type"])       
            rdf.convert
            file.write(RDFModeler.write_ntriples(rdf.statements)) if params[:filename]
          end
        else
          logger.info "deleted record: #{record.header.identifier.split(':').last}"
        end
      end
      file.close if file
      { :result => "saved!" }
    end
    
  end # end oai namespace
end
end
