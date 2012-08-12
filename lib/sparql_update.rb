require 'rdf/virtuoso'
#require_relative '../../rdf-virtuoso/lib/rdf/virtuoso'

module SparqlUpdate
  CONFIG           = YAML::load_file('config/config.yml')
  @store           = CONFIG['rdfstore']['store']
  @sparql_endpoint = CONFIG['rdfstore']['sparql_endpoint']
  @sparul_endpoint = CONFIG['rdfstore']['sparul_endpoint']
  @default_graph   = RDF::URI(CONFIG['rdfstore']['default_graph'])
  @default_prefix  = CONFIG['rdfstore']['default_prefix']
  @username        = CONFIG['rdfstore']['username']
  @password        = CONFIG['rdfstore']['password']
  @auth_method     = CONFIG['rdfstore']['auth_method']
  @key             = CONFIG['rdfstore']['key']
  
  if @store == 'virtuoso'
    UPDATE_CLIENT = RDF::Virtuoso::Repository.new(@sparul_endpoint, :username => @username, :password => @password, :auth_method => @auth_method)
    QUERY  = RDF::Virtuoso::Query
  else
    # TODO: implement generic RestClient
    UPDATE_CLIENT = RestClient::Resource.new(@sparul_endpoint, :user => @username, :password => @password)
    QUERY  = RDF::Virtuoso::Query    
  end
  

    @prefixes = [
"local: <#{@default_prefix}>",
"rev: <http://purl.org/stuff/rev#>",
"foaf: <http://xmlns.com/foaf/0.1/>",
"owl: <http://www.w3.org/2002/07/owl#>",
"bibo: <http://purl.org/ontology/bibo/>",
    ]
      
  def self.sparql_delete(titlenumber, options={})
    resource = RDF::URI(CONFIG['resource']['base'] + CONFIG['resource']['resource_path'] + CONFIG['resource']['resource_prefix'] + titlenumber)
    
    if options[:preserve]
      minus = options[:preserve].collect { |p| [RDF::URI("#{resource}"), RDF.module_eval("#{p}"), :o] }
      # if :preserve contains an array of :minuses?
      if minus.first.is_a?(Array)
        query = QUERY.delete([resource, :p, :o]).graph(@default_graph).where([resource, :p, :o]).prefixes(@prefixes)
        minus.each {|m| query.minus(m) }
      else
        query = QUERY.delete([resource, :p, :o]).graph(@default_graph).where([resource, :p, :o]).minus(minus).prefixes(@prefixes)
      end
      puts query.to_s if $debug
      
      if @store == 'virtuoso'
        response = UPDATE_CLIENT.delete(query)
      else
        response = UPDATE_CLIENT.post :query => query.to_s, :key => @key
      end
    else
      query = QUERY.delete([resource, :p, :o]).graph(@default_graph).where([resource, :p, :o]).prefixes(@prefixes)
      puts query.to_s if $debug

      if @store == 'virtuoso'
        response = UPDATE_CLIENT.delete(query)
      else
        response = UPDATE_CLIENT.post :query => query.to_s, :key => @key
      end

    end
  end

  def self.sparql_purge(titlenumber)
    resource = RDF::URI(CONFIG['resource']['base'] + CONFIG['resource']['resource_path'] + CONFIG['resource']['resource_prefix'] + titlenumber)

    query = QUERY.delete([resource, :p, :o]).graph(@default_graph).where([resource, :p, :o]).prefixes(@prefixes)
    puts query.to_s if $debug

    if @store == 'virtuoso'
      response = UPDATE_CLIENT.delete(query)
    else
      response = UPDATE_CLIENT.post :query => query.to_s, :key => @key
    end
    
    query = QUERY.delete([:s, :p, resource]).graph(@default_graph).where([:s, :p, resource]).prefixes(@prefixes)
    puts query.to_s if $debug

    if @store == 'virtuoso'
      response = UPDATE_CLIENT.delete(query)
    else
      response = UPDATE_CLIENT.post :query => query.to_s, :key => @key
    end

  end
  
  def self.sparql_update(titlenumber, options={})
    preserve = options[:preserve] || nil
    ## delete resource first!
    sparql_delete(titlenumber, :preserve => preserve)

    ## then insert new triples

    query = QUERY.insert_data($statements).graph(@default_graph)
    puts query.to_s if $debug

    if @store == 'virtuoso'
      response = UPDATE_CLIENT.insert_data(query)
    else
      response = UPDATE_CLIENT.post :query => query.to_s, :key => @key
    end
    
  end  
end

