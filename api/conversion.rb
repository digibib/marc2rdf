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
      library = Library.new.find(:id => params[:id])
      reader = MARC::XMLReader.new('./spec/example.normarc.xml')
      record = Marshal.load(Marshal.dump(reader.first))
      rdf = RDFModeler.new(library.id, record, :mapping => params[:mapping])
      rdf.convert
      { :resource => rdf.statements }
    end
    
    desc "test: uploads a file to convert"
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
      library = Library.new.find(:id => params[:id])
      reader = MARC::ForgivingReader.new(filename)
      rdfrecords = []
      reader.first(20).each do |record|
        rdf = RDFModeler.new(library.id, record)
        rdf.set_type(library.config["resource"]["type"])
        rdf.convert
        rdf.write_record
        rdfrecords << rdf.statements
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
      library = Library.new.find(:id => params[:id])
      reader = MARC::ForgivingReader.new(upload)
      rdfrecords = []
      filename = "#{params[:file][:filename]}.nt"
      savefile = File.join(File.dirname(__FILE__), '../db/converted/', filename)
      file = File.open(savefile, 'a+') if params[:file][:filename]
      reader.each do |record|
        rdf = RDFModeler.new(library.id, record)
        rdf.set_type(library.config["resource"]["type"])
        rdf.convert
        rdf.write_record
        file.write(rdf.rdf)
        rdfrecords << rdf.statements
      end
      { :resource => rdfrecords[0..2], :filename => filename }
    end
        
  end # end convert namespace
end
end
