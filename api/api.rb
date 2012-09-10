#!/usr/bin/env ruby 
# encoding: UTF-8
if RUBY_VERSION <= "1.8.7" then $KCODE = 'u' end #needed for string conversion in ruby 1.8.7
require 'rubygems'
require 'bundler/setup'
require 'grape'
require_relative '../lib/rdfmodeler.rb'

SPARQL_ENDPOINT  = RDFModeler::CONFIG['rdfstore']['sparql_endpoint']
SPARUL_ENDPOINT  = RDFModeler::CONFIG['rdfstore']['sparul_endpoint']
DEFAULT_PREFIX   = RDFModeler::CONFIG['rdfstore']['default_prefix']
DEFAULT_GRAPH    = RDF::URI(RDFModeler::CONFIG['rdfstore']['default_graph'])

@username    = RDFModeler::CONFIG['rdfstore']['username']
@password    = RDFModeler::CONFIG['rdfstore']['password']
@auth_method = RDFModeler::CONFIG['rdfstore']['auth_method']

REPO  = RDF::Virtuoso::Repository.new(SPARQL_ENDPOINT, :update_uri => SPARUL_ENDPOINT, :username => @username, :password => @password, :auth_method => @auth_method)
QUERY = RDF::Virtuoso::Query

class RDFModeler
  class API < Grape::API
    prefix 'api'
    format :json
    default_format :json
  
    resource :books do
      desc "returns a total count of books in rdf store"
      get '/count' do
        count = Sparql::count(RDF::BIBO.Document)
        { :count => count }
      end

      desc "return literary formats found in store"
      get '/literaryFormats' do
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
end
