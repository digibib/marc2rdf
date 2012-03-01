require 'rubygems'
require 'rest_client'
require 'yaml'
require 'nokogiri'
require 'rdf'
require 'sparql/client'

CONFIG           = YAML::load_file('config/config.yml')
QUERY_ENDPOINT   = SPARQL::Client.new(CONFIG['rdfstore']['sparql_endpoint'])
SPARUL_ENDPOINT  = CONFIG['rdfstore']['sparul_endpoint']
DEFAULT_GRAPH    = CONFIG['rdfstore']['default_graph']
COVERART_SOURCES = CONFIG['coverart_sources']

@username = CONFIG['rdfstore']['username']
@password = CONFIG['rdfstore']['password']

  def fetch_cover_art(isbn)
    response = RestClient.get @url + isbn
    if @source == 'bokkilden' then bokkilden_cover(response) end
  end

  def bokkilden_cover(response)
    res = Nokogiri::XML(response)
    cover_url = res.xpath("/Produkter/Produkt/BildeURL").text
    cover_url.gsub('&width=80', '') if cover_url
  end

  def fetch_results(offset, limit)
  	isbns = []
  	# query to return books without foaf:depiction
    query = <<-eos
    PREFIX bibo: <http://purl.org/ontology/bibo/>
    PREFIX foaf: <http://xmlns.com/foaf/0.1/>

    SELECT ?book ?isbn WHERE {
      GRAPH <#{DEFAULT_GRAPH}> {
        ?book bibo:isbn ?isbn .
        MINUS { ?book foaf:depiction ?depiction }
      }
    } LIMIT #{limit} OFFSET #{offset}
    eos
    results = QUERY_ENDPOINT.query(query)

    @count = 0
    results.each do | solution |
      cover_url = fetch_cover_art(solution.isbn.value)
      unless cover_url.empty?
        query = <<-EOQ
        PREFIX foaf: <#{RDF::FOAF.to_s}>
        INSERT INTO <#{DEFAULT_GRAPH}> { <#{solution.book}> foaf:depiction <#{cover_url}> } 
        EOQ

        resource = RestClient::Resource.new(SPARUL_ENDPOINT, :user => @username, :password => @password)
        # p query.inspect
        result = resource.post :query => query
        @count += 1
      end
    end
     
  end

offset = 0

COVERART_SOURCES.each do | source, sourcevalue |
  limit = sourcevalue['limit']
  @url = sourcevalue['url']
  @source = source
  
  # loops over source, uses url and limit from yaml
  loop do    
    fetch_results(offset, limit)
    offset += limit
    # insert break for testing:
    # break if offset == 100 
  end
end
p @count
