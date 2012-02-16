module RestClient
  @endpoint = CONFIG['rdfstore']['sparul_endpoint']
  @default_graph = CONFIG['rdfstore']['default_graph']
  @username = CONFIG['rdfstore']['username']
  @password = CONFIG['rdfstore']['password']

  def self.sparql_delete(titlenumber)
    resource = CONFIG['resource']['base'] + CONFIG['resource']['resource_path'] + CONFIG['resource']['resource_prefix'] + titlenumber
    query = <<-EOQ
DELETE FROM GRAPH <#{@default_graph}> { <#{resource}> ?p ?o }
WHERE { GRAPH <#{@default_graph}> { <#{resource}> ?p ?o } }
EOQ
    resource = RestClient::Resource.new(@endpoint, :user => @username, :password => @password)
    resource.post :query => query
  end

  def self.sparql_insert(titlenumber)

    ## delete resource first!
    sparql_delete(titlenumber)

    ## then insert new triples
    ntriples = []
    $statements.each do | statement |
       ntriples << statement.to_ntriples
    end
    query = <<-EOQ
INSERT INTO GRAPH <#{@default_graph}> { #{ntriples.join} }
EOQ
    resource = RestClient::Resource.new(@endpoint, :user => @username, :password => @password)
    resource.post :query => query
  end  
end

