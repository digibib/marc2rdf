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
PREFIX local: <#{@default_prefix}>
PREFIX rev: <http://purl.org/stuff/rev#>
PREFIX foaf: <http://www.foafrealm.org/xfoaf/0.1/>
PREFIX owl: <http://www.w3.org/2002/07/owl#>
PREFIX bibo: <http://purl.org/ontology/bibo/>
#{@delete_statement} <#{@default_graph}> { <#{resource}> ?p ?o }
WHERE { GRAPH <#{@default_graph}> { <#{resource}> ?p ?o .
MINUS { <#{resource}> foaf:depiction ?depiction } 
MINUS { <#{resource}> rev:hasReview ?review } 
MINUS { <#{resource}> owl:sameAs ?sameAs } 
MINUS { <#{resource}> foaf:isVersionOf ?isVersionOf } 
MINUS { <#{resource}> bibo:isbn ?isbn } 

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

