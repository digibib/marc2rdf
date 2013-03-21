#!/usr/bin/env ruby 
#encoding: utf-8
module API
class Convert < Grape::API
  resource :convert do
    desc "test convert resource"
      params do
        requires :id, type: Integer, desc: "ID of library"
      end
    put "/test" do
      content_type 'json'
      library = Library.new.find(:id => params[:id])
      reader = MARC::XMLReader.new('./spec/example.normarc.xml')
      record = Marshal.load(Marshal.dump(reader.first))
      rdf = RDFModeler.new(library.id, record)
      rdf.convert
      { :resource => rdf.statements }
    end
  end # end convert namespace
end
end
