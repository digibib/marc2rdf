#encoding: utf-8
#Struct for SPARQL UPDATE class 
#handles deleting and update repository from harvest/convert

SparqlUpdate = Struct.new(:uri, :graph, :record, :isbn, :response, :library, :preserve)
class SparqlUpdate
  
  def initialize(record, library)
    # check if an RDF modeler object or just a RDF uri
    record.instance_of?(RDFModeler) ? self.uri = record.uri : self.uri = RDF::URI(library.config["resource"]["base"] + library.config["resource"]["prefix"] + "#{record}")
    self.library  = library
    self.preserve = library.oai['preserve_on_update']
    self.graph    = RDF::URI(library.config['resource']['default_graph'])
    self.record   = record
  end

  def modify_record
    delete_old_record
    delete_old_authorities
    insert_new_record
  end
  
  def delete_record
    purge_record
  end
   
  private
  
  # this method deletes record while preserving specified predicates
  def delete_old_record
    return nil unless self.uri
    query = QUERY.delete([self.uri, :p, :o]).graph(self.graph).where([self.uri, :p, :o])
    query.define('sql:log-enable 3')  # neccessary for concurrent writes
    if self.preserve
      minus = self.preserve.collect { |p| [self.uri, RDF.module_eval("#{p}"), :o] }
      minus.each {|m| query.minus(m) }
    end  
    #puts "DELETE query:\n #{query}" if ENV['RACK_ENV'] == 'development'
    ENV['RACK_ENV'] == 'test' ? 
      response = query.to_s : 
      response = REPO.delete(query)
  end

  def delete_old_authorities
    ## done by making temporary graph with converted record
    ## and do queries on this to find authorities to delete
    tempgraph = RDF::Graph.new('temp')
    self.record.statements.each {|s| tempgraph << s }
    
    ## NB: OPTIONAL is not implemented on RDF::Query yet, so we need to do nested queries
    auths = [RDF::FOAF.Person, 
            RDF::FOAF.Organization, 
            RDF::SKOS.Concept, 
            RDF::GEONAMES.Feature, 
            RDF::BIBO.Series, 
            RDF::YAGO.LiteraryGenres, 
            RDF::MO.Genre]
    
    authority_ids = []
    auths.each do |auth|
      authority_ids << RDF::Query.execute(tempgraph, {
        :id => { RDF.type => auth }
      })
    end
    # clean results before iterating
    authority_ids.delete_if {|s| s.empty? }.flatten!
    
    authority_ids.each do | auth |
      deleteauthquery = QUERY.delete([auth[:id], :p, :o]).graph(self.graph).where([auth[:id], :p, :o])
      deleteauthquery.minus([auth[:id], RDF::SKOS.broader, :o])
      deleteauthquery.minus([auth[:id], RDF::OWL.sameAs, :o])
      deleteauthquery.define('sql:log-enable 3')  # neccessary for concurrent writes
      #puts "Delete authorities:\n #{deleteauthquery}" if ENV['RACK_ENV'] == 'development'
      REPO.delete(deleteauthquery) unless ENV['RACK_ENV'] == 'test'
    end
    authority_ids
  end
  
  def insert_new_record
    ## insert new triples
    query = QUERY.insert_data(self.record.statements).graph(self.graph)
    query.define('sql:log-enable 3')  # neccessary for concurrent writes
    #puts "INSERT query:\n #{query}" if ENV['RACK_ENV'] == 'development'
    ENV['RACK_ENV'] == 'test' ? 
      response = query.to_s : 
      response = REPO.insert_data(query)
  end  
    
  def purge_record
    return nil unless self.uri
    query = QUERY.delete([self.uri, :p, :o],[:x, :y, self.uri])
    query.graph(self.graph).where([self.uri, :p, :o],[:x, :y, self.uri])
    query.define('sql:log-enable 3')  # neccessary for concurrent writes
    #puts "PURGE query:\n #{query}" if ENV['RACK_ENV'] == 'development'
    ENV['RACK_ENV'] == 'test' ?
      response = query.to_s : 
      response = REPO.delete(query)
  end
  
  ## Class methods
  
  # insert new harvested triples
  def self.insert_harvested_triples(graph, statements)
    query = QUERY.insert_data(statements)
    query.graph(graph)
    query.define('sql:log-enable 3')  # neccessary for concurrent writes
    ENV['RACK_ENV'] == 'test' ?
      response = query.to_s : 
      response = REPO.insert_data(query)
  end

end
