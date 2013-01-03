#!/usr/bin/env ruby 
# encoding: UTF-8
if RUBY_VERSION <= "1.8.7" then $KCODE = 'u' end #needed for string conversion in ruby 1.8.7
require 'rubygems'
require 'bundler/setup'
require 'grape'

# RDFmodeler loads all other classes in marc2rdf
#require_relative './lib/rdfmodeler.rb'

class API < Grape::API
  prefix 'api'
  format :json
  default_format :json

  resource :mapping do
    desc "get skeleton mapping"
    get "/" do
      { :mapping => Map.new('mapping.json') }
    end
    desc "return a certain mapping from id"
    get "/:id" do
      map = Map.new
      map.find_by_id(params[:id].to_s)
      throw :error, :status => 400,
            :message => "Mapping not found" unless map
      { :mapping => map.mapping }
    end
  end


  resource :books do
    desc "returns a total count of books in rdf store"
    get "/count" do
      count = Sparql::count(RDF::BIBO.Document)
      { :count => count }
    end

    desc "return literary formats found in store"
    get "/literaryFormats" do
      query = QUERY.select(:lf).where([:book, RDF::DEICHMAN.literaryFormat, :lf])
        .distinct
        .from(DEFAULT_GRAPH)
      solutions = REPO.select(query)
      { :literaryFormats => solutions.bindings }
    end
    
    desc "lookup a book by titlenumber"
    get '/:tnr' do
      tnr = params[:tnr].to_s
      query = QUERY.select.where(
        [:id, RDF::DC.identifier, "#{tnr}"],
        [:id, RDF::DC.title, :title],
        [:id, RDF::DC.creator, :creator_id],
        [:creator_id, RDF::RADATANA.catalogueName, :creator],
        [:id, RDF::BIBO.isbn, :isbn]
        )
        .distinct
        .from(DEFAULT_GRAPH)
        .optional([:book, RDF::FOAF.depiction, :cover_url])
      solutions = REPO.select(query)
      { :book => solutions.bindings }
    end
  end
  
end
