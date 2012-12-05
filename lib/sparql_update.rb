require 'rdf/virtuoso'
require_relative './rdfmodeler.rb'

module SparqlUpdate
  CONFIG           = YAML::load_file('config/config.yml')
  STORE           = CONFIG['rdfstore']['store']
  SPARQL_ENDPOINT = CONFIG['rdfstore']['sparql_endpoint']
  SPARUL_ENDPOINT = CONFIG['rdfstore']['sparul_endpoint']
  DEFAULT_GRAPH   = RDF::URI(CONFIG['rdfstore']['default_graph'])
  DEFAULT_PREFIX  = CONFIG['rdfstore']['default_prefix']
  
  @username        = CONFIG['rdfstore']['username']
  @password        = CONFIG['rdfstore']['password']
  @auth_method     = CONFIG['rdfstore']['auth_method']
  @key             = CONFIG['rdfstore']['key']
  
  if STORE == 'virtuoso'
    UPDATE_CLIENT = RDF::Virtuoso::Repository.new(SPARQL_ENDPOINT, :update_uri => SPARUL_ENDPOINT, :username => @username, :password => @password, :auth_method => @auth_method)
    QUERY  = RDF::Virtuoso::Query
  else
    # TODO: implement generic RestClient
    UPDATE_CLIENT = RestClient::Resource.new(SPARUL_ENDPOINT, :user => @username, :password => @password)
    QUERY  = RDF::Virtuoso::Query    
  end

  @prefixes = [
"local: <#{DEFAULT_PREFIX}>",
"rev: <http://purl.org/stuff/rev#>",
"foaf: <http://xmlns.com/foaf/0.1/>",
"owl: <http://www.w3.org/2002/07/owl#>",
"bibo: <http://purl.org/ontology/bibo/>",
    ]
end

class SPARUL
  include SparqlUpdate
  def self.sparul_insert(statements)
    unless statements.empty?
      query = QUERY.insert_data(statements).graph(DEFAULT_GRAPH)
      puts query.to_s if $debug
      #puts statements.each { |s| s.to_s } if $debug
      statements.each {|statement| $output_file << RDF::NTriples.serialize(statement) } if $output_file
      result = REPO.insert_data(query) if $insert
    end
  end
end

class OAIUpdate
  include SparqlUpdate
  def self.sparql_delete(titlenumber, options={})
    resource = RDF::URI(CONFIG['resource']['base'] + CONFIG['resource']['resource_path'] + CONFIG['resource']['resource_prefix'] + titlenumber)
    
    if options[:preserve]
      minus = options[:preserve].collect { |p| [RDF::URI("#{resource}"), RDF.module_eval("#{p}"), :o] }
      # if :preserve contains an array of :minuses?
      if minus.first.is_a?(Array)
        query = QUERY.delete([resource, :p, :o]).graph(DEFAULT_GRAPH).where([resource, :p, :o]).prefixes(@prefixes)
        minus.each {|m| query.minus(m) }
      else
        query = QUERY.delete([resource, :p, :o]).graph(DEFAULT_GRAPH).where([resource, :p, :o]).minus(minus).prefixes(@prefixes)
      end
      puts query.to_s if $debug
      
      if STORE == 'virtuoso'
        response = UPDATE_CLIENT.delete(query)
      else
        response = UPDATE_CLIENT.post :query => query.to_s, :key => @key
      end
    else
      query = QUERY.delete([resource, :p, :o]).graph(DEFAULT_GRAPH).where([resource, :p, :o]).prefixes(@prefixes)
      puts query.to_s if $debug

      if STORE == 'virtuoso'
        response = UPDATE_CLIENT.delete(query)
      else
        response = UPDATE_CLIENT.post :query => query.to_s, :key => @key
      end

    end
  end

  def self.sparql_purge(titlenumber)
    resource = RDF::URI(CONFIG['resource']['base'] + CONFIG['resource']['resource_path'] + CONFIG['resource']['resource_prefix'] + titlenumber)

    query = QUERY.delete([resource, :p, :o]).graph(DEFAULT_GRAPH).where([resource, :p, :o]).prefixes(@prefixes)
    puts query.to_s if $debug

    if STORE == 'virtuoso'
      response = UPDATE_CLIENT.delete(query)
    else
      response = UPDATE_CLIENT.post :query => query.to_s, :key => @key
    end
    
    query = QUERY.delete([:s, :p, resource]).graph(DEFAULT_GRAPH).where([:s, :p, resource]).prefixes(@prefixes)
    puts query.to_s if $debug

    if STORE == 'virtuoso'
      response = UPDATE_CLIENT.delete(query)
    else
      response = UPDATE_CLIENT.post :query => query.to_s, :key => @key
    end

  end
  
  def self.sparql_update(titlenumber, options={})
    preserve = options[:preserve] || nil
    ## 1. delete resource first!
    self.sparql_delete(titlenumber, :preserve => preserve)

    ## 2. then delete authorities!
    tempgraph = RDF::Graph.new('temp')
    $statements.each {|s| tempgraph << s }
    
    authority_ids = RDF::Query.execute(tempgraph, {
      :persons        => { RDF.type => RDF::FOAF.Person },
      :organizations  => { RDF.type => RDF::FOAF.Organization },
      :subjects       => { RDF.type => RDF::SKOS.Concept }, 
      :geonames       => { RDF.type => RDF::GEONAMES.Feature }, 
      :series         => { RDF.type => RDF::BIBO.Series },
      :mogenres       => { RDF.type => RDF::MO.Genre },
      :literaryGenres => { RDF.type => RDF::YAGO.LiteraryGenres }
    })
    
    authority_ids.each do | auth |
      deleteauthquery = QUERY.delete.where([auth, :p, :o])
      puts "Delete authorities:\n #{deleteauthquery.to_s}" if $debug
      result = REPO.delete(deleteauthquery).graph(DEFAULT_GRAPH)
    end
    
    ## then insert new triples

    query = QUERY.insert_data($statements).graph(DEFAULT_GRAPH)
    puts query.to_s if $debug

    if STORE == 'virtuoso'
      response = UPDATE_CLIENT.insert_data(query)
    else
      response = UPDATE_CLIENT.post :query => query.to_s, :key => @key
    end
    
  end  
end
