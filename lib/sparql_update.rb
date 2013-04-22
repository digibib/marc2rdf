#encoding: utf-8
#Struct for SPARQL UPDATE class 
#handles deleting and update repository from harvest/convert

SparqlUpdate = Struct.new(:uri, :graph, :record, :isbn, :response, :library, :preserve)
class SparqlUpdate
  
  def initialize(record, library)
    self.uri      = record.uri
    self.library  = library
    self.preserve = library.oai['preserve_on_update']
    self.graph    = RDF::URI(library.config['resource']['default_graph'])
    self.record   = record
  end

  def update_record
    delete_record
    delete_authorities
    insert_record
  end
    
  # this method deletes record while preserving specified predicates
  def delete_record
    return nil unless self.uri
    if self.preserve
      minus = self.preserve.collect { |p| [self.uri, RDF.module_eval("#{p}"), :o] }
      query = QUERY.delete([self.uri, :p, :o]).graph(self.graph).where([self.uri, :p, :o])
      minus.each {|m| query.minus(m) }
    end  
    puts "query:\n #{query.pp}" if ENV['RACK_ENV'] == 'development'
    ENV['RACK_ENV'] == 'test' ? 
      response = query.to_s : 
      response = REPO.delete(query)
  end

  def delete_authorities
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
      puts "Delete authorities:\n #{deleteauthquery.pp}" if ENV['RACK_ENV'] == 'development'
      REPO.delete(deleteauthquery) unless ENV['RACK_ENV'] == 'test'
    end
    authority_ids
  end
  
  def insert_record
    ## insert new triples
    query = QUERY.insert_data(self.record.statements).graph(self.graph)
    puts "query:\n #{query.pp}" if ENV['RACK_ENV'] == 'development'
    ENV['RACK_ENV'] == 'test' ? 
      response = query.to_s : 
      response = REPO.insert_data(query)
  end  
    
  def purge_record
    return nil unless self.uri
    query = QUERY.delete([self.uri, :p, :o],[:x, :y, self.uri])
    query.graph(self.graph).where([self.uri, :p, :o],[:x, :y, self.uri])
    puts "query:\n #{query.pp}" if ENV['RACK_ENV'] == 'development'
    ENV['RACK_ENV'] == 'test' ?
      response = query.to_s : 
      response = REPO.delete(query)
  end

end
