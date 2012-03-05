module RestClient
  @store = CONFIG['rdfstore']['store']
  @endpoint = CONFIG['rdfstore']['sparul_endpoint']
  @default_graph = CONFIG['rdfstore']['default_graph']
  @default_prefix = CONFIG['rdfstore']['default_prefix']
  @username = CONFIG['rdfstore']['username']
  @password = CONFIG['rdfstore']['password']
  @key = CONFIG['rdfstore']['key']
  
  @delete_statement = 'DELETE FROM'
  @insert_statement = 'INSERT INTO'

  def self.sparql_delete(titlenumber)
    resource = CONFIG['resource']['base'] + CONFIG['resource']['resource_path'] + CONFIG['resource']['resource_prefix'] + titlenumber
    query = <<-EOQ
PREFIX local: <#{DEFAULT_PREFIX}>
#{@delete_statement} <#{@default_graph}> { <#{resource}> ?p ?o }
WHERE { GRAPH <#{@default_graph}> { <#{resource}> ?p ?o .
MINUS { <#{resource}> local:depiction_bokkilden ?depiction } 
MINUS { <#{resource}> local:depiction_onskebok ?depiction } 
} }
EOQ
    puts query if $debug
    resource = RestClient::Resource.new(@endpoint, :user => @username, :password => @password)
    resource.post :query => query, :key => @key
  end

  def self.sparql_update(titlenumber)

    ## delete resource first!
    sparql_delete(titlenumber)

    ## then insert new triples
    ntriples = []
    $statements.each do | statement |
       ntriples << statement.to_ntriples
    end
    query = <<-EOQ
#{@insert_statement} <#{@default_graph}> { #{ntriples.join} }
EOQ
    puts query if $debug
    resource = RestClient::Resource.new(@endpoint, :user => @username, :password => @password)
    resource.post :query => query, :key => @key
  end  
end

