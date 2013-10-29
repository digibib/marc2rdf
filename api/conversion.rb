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
    
    desc "test: uploads a file, converts first 20 records"
      params do
        requires :id, type: Integer, desc: "ID of library"
        requires :file,  desc: "File to convert"
      end    
    post "/uploadtest" do
      puts request.body
      filename = File.join(File.dirname(__FILE__), '../db/uploads', params[:file][:filename])
      FileUtils.cp(params[:file][:tempfile], filename) 
      logger.info "Success: #{params[:file][:filename]} uploaded."
      # converting ...
      library = Library.find(:id => params[:id])
      reader = MARC::ForgivingReader.new(filename)
      rdfrecords = []
      reader.first(20).each do |record|
        rdf = RDFModeler.new(library.id, record)
        rdf.set_type(library.config["resource"]["type"])
        rdf.convert
        rdf.statements.each {|s| rdfrecords.push(s)}
      end
      { :resource => rdfrecords }
    end

    desc "uploads a file to convert"
      params do
        requires :id, type: Integer, desc: "ID of library"
        requires :file,  desc: "File to convert"
      end    
    post "/upload" do
      upload = File.join(File.dirname(__FILE__), '../db/uploads', params[:file][:filename])
      FileUtils.cp(params[:file][:tempfile], upload) 
      logger.info "Success: #{params[:file][:filename]} uploaded."
      # converting ...
      library = Library.find(:id => params[:id])
      reader = MARC::ForgivingReader.new(upload)
      rdfrecords = []
      filename = "#{params[:file][:filename]}.nt"
      savefile = File.join(File.dirname(__FILE__), '../db/converted/', filename)
      file = File.open(savefile, 'a+') if params[:file][:filename]
      reader.each do |record|
        rdf = RDFModeler.new(library.id, record)
        rdf.set_type(library.config["resource"]["type"])
        rdf.convert
        rdf.statements.each {|s| rdfrecords.push(s)}
      end
      file.write(RDFModeler.write_ntriples(rdfrecords)) if file
      { :resource => rdfrecords[0..2], :filename => filename }
    end

    desc "return marcxml from resource"
      params do
        requires :id, type: Integer, desc: "ID of library"
        requires :uri, type: String, desc: "URI of resource"
      end
    get "/marcxml" do
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
