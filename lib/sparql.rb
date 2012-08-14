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
    query    = QUERY.select.where([:s, RDF.type, type]).count(:s).distinct.graph(DEFAULT_GRAPH)
    puts query.to_s if $debug
    solutions = REPO.select(query)
    count = solutions.first[:count].to_i
  end

  def self.rdfstore_isbnlookup(offset, limit)
    #if $debug then puts "offset: #{offset}" end
    prefixes = RDF::Virtuoso::Prefixes.new bibo: "http://purl.org/ontology/bibo/", foaf: "http://xmlns.com/foaf/0.1/", local: "#{DEFAULT_PREFIX}"
    #minuses = [:book, RDF::FOAF.depiction, :object]
    query = QUERY.select(:book, :isbn).where([:book, RDF::type, RDF::BIBO.Document],[:book, RDF::BIBO.isbn, :isbn]).prefixes(prefixes).offset(offset).limit(limit)
    puts query.to_s if $debug
    solutions = REPO.select(query)
  end

end
