#!/usr/bin/env ruby 
#encoding: utf-8
module API
class Conversion < Grape::API
  resource :conversion do
    desc "test mapping conversion of xml resource"
      params do
        requires :id, type: Integer, desc: "ID of library"
        optional :mapping, type: String, desc: "ID of mapping"
      end
    put "/test" do
      content_type 'json'
      library = Library.find(:id => params[:id])
      reader = MARC::XMLReader.new('./spec/example.normarc.xml')
      record = Marshal.load(Marshal.dump(reader.first))
      rdf = RDFModeler.new(library.id, record, :mapping => params[:mapping])
      rdf.convert
      { :resource => rdf.statements }
    end
    
    desc "uploads a file to convert or grabs from URL"
      params do
        requires :id, type: Integer, desc: "ID of library"
        optional :file,  desc: "File to convert"
        optional :url, type: String, desc: "URL to XML Resource or API"
        optional :test, type: Boolean, desc: "true|false"
        optional :save, type: Boolean, desc: "true|false"
      end    
    post "/upload" do
      logger.info params
      error!("Need file upload or URL to test!", 400) unless params[:file] or params[:url]
      library = Library.find(:id => params[:id])
      if params[:file]
        unless ["text/xml", "application/xml", "application/octet-stream"].include? params[:file][:type]
          error!("Only MARCXML or Binary MARC supported!", 400)
        end
        upload = File.join(File.dirname(__FILE__), '../db/uploads', params[:file][:filename])
        FileUtils.cp(params[:file][:tempfile], upload) 
        logger.info "Success: #{params[:file][:filename]} of filetype #{params[:file][:type]} uploaded."
        # choose MARC reader by mime-type
        params[:file][:type] == "application/octet-stream" ? reader = MARC::ForgivingReader.new(upload) :
          reader = MARC::XMLReader.new(upload)
      else
        uri = URI.parse(params[:url])
        response = Net::HTTP.get_response(uri)
        reader = MARC::XMLReader.new(StringIO.new(response.body))
      end
      # converting ...
      if params[:save]
        if params[:file]
          filename = "#{params[:file][:filename]}.nt"
        else
          filename = "#{Time.now.strftime('%Y-%m-%d-%H%M%S')}-from-URL.nt"
        end
        savefile = File.join(File.dirname(__FILE__), '../db/converted/', filename)
        file = File.open(savefile, 'a+') 
      end
      reader = reader.entries.take(3) if params[:test]
      
      rdfrecords = []
      reader.each do |record|
        rdf = RDFModeler.new(library.id, record)
        rdf.set_type(library.config["resource"]["type"])
        rdf.convert
        rdf.statements.each {|s| rdfrecords.push(s)}
      end
      file.write(RDFModeler.write_ntriples(rdfrecords)) if file
      file.close if file
      { :resource => rdfrecords, :filename => filename }
    end

    desc "return marcxml from resource"
      params do
        requires :id, type: Integer, desc: "ID of library"
        requires :uri, type: String, desc: "URI of resource"
      end
    get "/marcxml" do
      #format :xml
      #content_type :xml, 'text/xml'
      content_type 'text/xml'
      library = Library.find(:id => params[:id])
      marc = MARCModeler.new(library)
      marc.get_manifestation(params[:uri])
      marc.convert
      error!("Resource not found: #{params[:uri]}", 404) unless marc.marc
      marc
    end    

  end # end convert namespace
end
end
