#!/usr/bin/env ruby 
#encoding: utf-8
module API
class Conversion < Grape::API
  resource :conversion do
    desc "test convert xml resource"
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
    
    desc "uploads a file to convert"
      #params do
      #  requires :file,  desc: "File to convert"
      #end    
    post "/upload" do
      puts request.body
      filename = File.join(File.dirname(__FILE__), '../db/uploads', params[:file][:filename])
      FileUtils.cp(params[:file][:tempfile], filename) 
      "success!"
    end
  end # end convert namespace
end
end
