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

  def self.sparql_delete(titlenumber, options={})
    resource = CONFIG['resource']['base'] + CONFIG['resource']['resource_path'] + CONFIG['resource']['resource_prefix'] + titlenumber
    if options[:preserve]
      @minus = options[:preserve].collect { |p| "MINUS { <#{resource}> <" + RDF.module_eval("#{p}") + "> ?o } " }
    end
    query = <<-EOQ
PREFIX local: <#{@default_prefix}>
PREFIX rev: <http://purl.org/stuff/rev#>
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
PREFIX owl: <http://www.w3.org/2002/07/owl#>
PREFIX bibo: <http://purl.org/ontology/bibo/>
#{@delete_statement} <#{@default_graph}> { <#{resource}> ?p ?o }
WHERE { GRAPH <#{@default_graph}> { <#{resource}> ?p ?o .
#{@minus.join}
} }
EOQ
    puts query if $debug
    sparqlclient = RestClient::Resource.new(@endpoint, :user => @username, :password => @password)
    sparqlclient.post :query => query, :key => @key
  end

  def self.sparql_purge(titlenumber)
    resource = CONFIG['resource']['base'] + CONFIG['resource']['resource_path'] + CONFIG['resource']['resource_prefix'] + titlenumber
    resource_as_subject = <<-EOQ
PREFIX local: <#{@default_prefix}>
PREFIX rev: <http://purl.org/stuff/rev#>
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
PREFIX owl: <http://www.w3.org/2002/07/owl#>
PREFIX bibo: <http://purl.org/ontology/bibo/>
#{@delete_statement} <#{@default_graph}> { <#{resource}> ?p ?o }
WHERE { GRAPH <#{@default_graph}> { <#{resource}> ?p ?o } }
EOQ
    puts resource_as_subject if $debug
    sparqlclient = RestClient::Resource.new(@endpoint, :user => @username, :password => @password)
    sparqlclient.post :query => resource_as_subject, :key => @key

    resource_as_object = <<-EOQ
PREFIX local: <#{@default_prefix}>
PREFIX rev: <http://purl.org/stuff/rev#>
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
PREFIX owl: <http://www.w3.org/2002/07/owl#>
PREFIX bibo: <http://purl.org/ontology/bibo/>
#{@delete_statement} <#{@default_graph}> { ?s ?p <#{resource}> }
WHERE { GRAPH <#{@default_graph}> { ?s ?p <#{resource}> } }
EOQ
    puts resource_as_object if $debug
    sparqlclient = RestClient::Resource.new(@endpoint, :user => @username, :password => @password)
    sparqlclient.post :query => resource_as_object, :key => @key
  end
  
  def self.sparql_update(titlenumber, options={})
    preserve =  options[:preserve] || nil
    ## delete resource first!
    sparql_delete(titlenumber, :preserve => preserve)

    ## then insert new triples
    ntriples = []
    $statements.each do | statement |
       ntriples << statement.to_ntriples
    end
    query = <<-EOQ
#{@insert_statement} <#{@default_graph}> { #{ntriples.join} }
EOQ
    puts query if $debug
    sparqlclient = RestClient::Resource.new(@endpoint, :user => @username, :password => @password)
    sparqlclient.post :query => query, :key => @key
  end  
end

