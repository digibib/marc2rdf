require 'rubygems'
require 'bundler/setup'
#require 'rest_client'
require 'base64'
require 'yaml'
require 'nokogiri'
require 'rdf'
require 'rdf/rdfxml'
require 'rdf/ntriples'
require 'sparql/client'

CONFIG           = YAML::load_file('config/config.yml')
QUERY_ENDPOINT   = SPARQL::Client.new(CONFIG['rdfstore']['sparql_endpoint'])
SPARUL_ENDPOINT  = CONFIG['rdfstore']['sparul_endpoint']
DEFAULT_PREFIX    = CONFIG['rdfstore']['default_prefix']
DEFAULT_GRAPH    = CONFIG['rdfstore']['default_graph']
COVERART_SOURCES = CONFIG['harvesting_sources']['coverart']

# SPARUL 
username = CONFIG['rdfstore']['username']
password = CONFIG['rdfstore']['password']
enc = "Basic " + Base64.encode64("#{username}:#{password}")
@sparul_client = SPARQL::Client.new("#{SPARUL_ENDPOINT}", :headers => {"Authorization" => "#{enc}"})

def usage(s)
    $stderr.puts(s)
    $stderr.puts("Usage: \n")
    $stderr.puts("#{File.basename($0)} -o output_file [-r recordlimit]\n")
    $stderr.puts("  -r [number] stops processing after given number of records\n")
    $stderr.puts("  -o [number] offset for start of harvest\n")    
    $stderr.puts("  -d debug output\n")
    exit(2)
end

loop { case ARGV[0]
    when '-r' then  ARGV.shift; $recordlimit = ARGV.shift.to_i # force integer
    when '-o' then  ARGV.shift; $offset = ARGV.shift.to_i # force integer    
    when '-d' then  ARGV.shift; $debug = true
    when /^-/ then  usage("Unknown option: #{ARGV[0].inspect}")
    else 
    break
end; }

  def fetch_cover_art(isbn)
    response = @http_persistent.request URI "#{@prefix}#{isbn}#{@suffix}#{@apikey}"
    
    # make sure we get valid response
    if response.code == "200"
      res = Nokogiri::XML(response.body)
      if @source == 'bokkilden' 
        cover_url = res.xpath("/Produkter/Produkt/BildeURL").text
        cover_url.gsub('&width=80', '') if cover_url
      end
      if @source == 'openlibrary' 
        cover_url = res.xpath('//sparql:uri', 'sparql' => 'http://www.w3.org/2005/sparql-results#').text
      end
    end
    cover_url
  end

  def fetch_results(offset, limit)
  	isbns = []
  	# query to return books without foaf:depiction
    query = <<-eos
    PREFIX bibo: <http://purl.org/ontology/bibo/>
    PREFIX foaf: <http://xmlns.com/foaf/0.1/>
    PREFIX local: <#{DEFAULT_PREFIX}>

    SELECT ?book ?isbn WHERE {
      GRAPH <#{DEFAULT_GRAPH}> {
        ?book bibo:isbn ?isbn ;
            a bibo:Document .
        MINUS { ?book local:depiction_#{@source} ?depiction }
      }
    } LIMIT #{limit} OFFSET #{offset}
    eos
    if $debug then puts "offset: #{offset}" end
    results = QUERY_ENDPOINT.query(query)

    @count = 0
    results.each do | solution |
      
      cover_url = fetch_cover_art(solution.isbn.value)
      unless cover_url.empty?
 
        # SPARQL UPDATE
        @local = RDF::Vocabulary.new "#{DEFAULT_PREFIX}"
        query = @sparul_client.insert([RDF::URI.new("#{solution.book}"), @local.depiction_ + "#{@source}", RDF::URI.new("#{cover_url}") ]).graph(RDF::URI.new("#{DEFAULT_GRAPH}"))
        if $debug then puts query.result.inspect end
        @count += 1
      end
    end
     
  end

unless $offset then $offset = 0 end

COVERART_SOURCES.each do | source, sourcevalue |
  limit = sourcevalue['limit']
  @prefix = sourcevalue['prefix']
  @suffix = sourcevalue['suffix']
  @apikey = sourcevalue['apikey']
  @source = source
  @http_persistent = Net::HTTP::Persistent.new "#{@source}"
  
  # next if @source == 'bokkilden'
  # loops over source, uses url and limit from yaml
  loop do    
    fetch_results($offset, limit)
    $offset += limit
    if $recordlimit then break if @count > $recordlimit end
  end
end
p @count
