#!/usr/bin/env ruby 
#encoding: utf-8
module API
class Oai < Grape::API
  resource :oai do
    desc "validate a OAI repository"
      params do
        requires :id, type: Integer, desc: "ID of library"
      end
    get "/validate" do
      content_type 'json'
      library = Library.new.find(:id => params[:id].to_i)
      logger.info "library: #{library.oai}"
      oai = OAIClient.new(library.oai["url"], 
        :format => library.oai["format"], 
        :parser => library.oai["parser"], 
        :timeout => library.oai["timeout"],
        :redirects => library.oai["timeout"])
      oai.validate
      return  { :result => "not validated!" } unless oai.identify_response
      { :repo => oai.identify_response, :id => oai.oai_id, :datasets => oai.datasets.inspect }
    end 

=begin
  deprecated, validate instead
    desc "identify a OAI repository"
      params do
        requires :id, type: Integer, desc: "ID of library"
      end
    get "/identify" do
      content_type 'json'
      library = Library.new.find(:id => params[:id].to_i)
      logger.info "library: #{library.oai}"
      oai = OAIClient.new(library.oai["url"], 
        :format => library.oai["format"], 
        :parser => library.oai["parser"], 
        :timeout => library.oai["timeout"],
        :redirects => library.oai["timeout"])
      result = oai.client.identify
      { :result => result }
    end 
=end
    desc "get a record"
      params do
        requires :id,       type: Integer, desc: "ID of library"
        requires :record,   type: String, desc: "Record identifier" 
        optional :filename, type: String, desc: "Filename, for saving" 
      end
    put "/getrecord" do
      content_type 'json'
      library = Library.new.find(:id => params[:id].to_i)
      oai = OAIClient.new(library.oai["url"], 
        :format => library.oai["format"], 
        :parser => library.oai["parser"], 
        :timeout => library.oai["timeout"],
        :redirects => library.oai["timeout"])
      unless params[:record].empty?
        oai.get_record :identifier => params[:record], :metadata_prefix => library.oai["format"]
      else
        oai.get_record :metadata_prefix => library.oai["format"]
      end
      xmlreader = MARC::XMLReader.new(StringIO.new(oai.records.record.metadata.to_s)) 
      rdfrecords = []
      if params[:filename]
        file = File.open(File.join(File.dirname(__FILE__), '../db/converted/', "#{params[:filename]}"), 'a+')
      end
      xmlreader.each do |marc|
        rdf = RDFModeler.new(library.id, marc)
        rdf.set_type(library.config["resource"]["type"])        
        rdf.convert
        rdfrecords << rdf.statements
        if file
          rdf.write_record
          file.write(rdf.rdf)
        end
      end
      { :resource => rdfrecords }
    end 
            
    desc "harvest a record batch"
      params do
        requires :id,            type: Integer,  desc: "ID of library"
        optional :from,          type: DateTime, desc: "From Date"
        optional :until,         type: DateTime, desc: "To Date"
        optional :tags,          type: String,   desc: "Tags"
        optional :write_records, type: Boolean,  desc: "Write converted records to file"
        optional :sparql_update, type: Boolean,  desc: "Update Repository directly"
      end
    put "/harvest" do
      content_type 'json'
      # Schedule harvest with from/until optional params, default from yesterday
      result = Scheduler.start_oai_harvest :id => params[:id].to_i,
          :from  => params[:from]  ||= Date.today.prev_day.to_s,
          :until => params[:until] ||= Date.today.to_s,
          :tags  => params[:tags]
      { :result => result }
    end 

    ## NEEDS FIXING ##
    desc "saves a record batch"
      params do
        requires :id,       type: Integer, desc: "ID of library"
        optional :from,     type: DateTime, desc: "From Date"
        optional :until,    type: DateTime, desc: "To Date"
        optional :filename, type: String, desc: "Filename, for saving" 
      end
    put "/save" do
      content_type 'json'
      library = Library.new.find(:id => params[:id].to_i)
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
            rdf.write_record
            file.write(rdf.rdf) if params[:filename]
          end
        else
          logger.info "deleted record: #{record.header.identifier.split(':').last}"
        end
      end
      { :result => "saved!" }
    end
    
  end # end oai namespace
end
end
