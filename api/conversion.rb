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
  end # end convert namespace
end
end
