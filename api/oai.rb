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
      result = oai.validate
      { :result => result }
    end 

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
        
    desc "harvest a record batch"
      params do
        requires :id,         type: Integer,  desc: "ID of library"
        optional :from,       type: DateTime, desc: "From Date"
        optional :until,      type: DateTime, desc: "To Date"
        optional :start_time, type: Time,     desc: "Time to schedule"
        optional :tag,        type: String,   desc: "Tag string"
      end
    put "/harvest" do
      content_type 'json'
      result = Scheduler.start_oai_harvest :id => params[:id].to_i,
          :from  => params[:from]  ||= Date.today.prev_day.to_s,
          :until => params[:until] ||= Date.today.to_s
      { :result => result }
    end 

    desc "saves a record batch"
      params do
        requires :id,    type: Integer, desc: "ID of library"
        optional :from,  type: DateTime, desc: "From Date"
        optional :until, type: DateTime, desc: "To Date"
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
      FileUtils.mkdir_p File.join(File.dirname(__FILE__), 'db', "#{library.id}")
      file = File.open(File.join(File.dirname(__FILE__), 'db', "#{library.id}", 'test.nt'), 'w')
      oai.response.entries.each do |record| 
        unless record.deleted?
          xmlreader = MARC::XMLReader.new(StringIO.new(record.metadata.to_s)) 
          xmlreader.each do |marc|
            rdf = RDFModeler.new(library.id, marc)
            rdf.set_type("BIBO.Document")        
            rdf.convert
            file.write(rdf.statements)
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
