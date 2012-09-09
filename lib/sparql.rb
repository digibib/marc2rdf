require 'rdf/virtuoso'
require_relative './rdfmodeler.rb'

module Sparql
CONFIG           = YAML::load_file('config/config.yml')
SPARQL_ENDPOINT  = CONFIG['rdfstore']['sparql_endpoint']
DEFAULT_PREFIX   = CONFIG['rdfstore']['default_prefix']
DEFAULT_GRAPH    = RDF::URI(CONFIG['rdfstore']['default_graph'])

REPO = RDF::Virtuoso::Repository.new(SPARQL_ENDPOINT)
QUERY  = RDF::Virtuoso::Query

  def self.count(type)
    query    = QUERY.select.where([:s, RDF.type, type]).distinct
      .count(:s)
      .from(DEFAULT_GRAPH)
    puts query.to_s if $debug
    solutions = REPO.select(query)
    count = solutions.first[:s].to_i
  end

  def self.rdfstore_isbnlookup(offset, limit)
    if $debug then puts "offset: #{offset}" end
    #minuses = [:book, RDF::FOAF.depiction, :object]
    query = QUERY.select(:book, :isbn)
      .from(DEFAULT_GRAPH)
      .where([:book, RDF::type, RDF::BIBO.Document],[:book, RDF::BIBO.isbn, :isbn])
      .offset(offset).limit(limit)
    puts query.to_s if $debug
    solutions = REPO.select(query)
  end

end
