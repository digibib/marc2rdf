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
    query.count(:s)
    query.from(DEFAULT_GRAPH)
    puts query.to_s if $debug
    solutions = REPO.select(query)
    count = solutions.first[:s].to_i
  end

  def self.rdfstore_lookup(options={})
    # lookup in RDF repository with options from config file
    minuses   = options[:minuses]   || nil
    limit     = options[:limit]     || nil
    offset    = options[:offset]    || nil
    # predicate to lookup, defaults to isbn
    predicate = options[:predicate] || "RDF::BIBO.isbn"
  
    if $debug then puts "offset: #{offset}" end

    if minuses
      minus = minuses.map { |m| [:book, RDF.module_eval("#{m}"), :object] }
    end

    query = QUERY.select(:work, :book, :object)
    query.from(DEFAULT_GRAPH)
    query.where(
      [:book, RDF.type, RDF::BIBO.Document],
      [:book, RDF.module_eval("#{predicate}"), :object],
      [:work, RDF::FABIO.hasManifestation, :book])
      minus.each {|m| query.minus(m) } if minuses
    query.offset(offset) if offset
    query.limit(limit) if limit
    
    puts query.to_s if $debug
    solutions = REPO.select(query)
  end

end
