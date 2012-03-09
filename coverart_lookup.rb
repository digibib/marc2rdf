# encoding: UTF-8
if RUBY_VERSION <= "1.8.7" then $KCODE = 'u' end #needed for string conversion in ruby 1.8.7
require 'rubygems'
require 'bundler/setup'
require 'base64'
require 'yaml'
require 'nokogiri'
require 'rdf'
require 'rdf/rdfxml'
require 'rdf/ntriples'
require 'sparql/client'

CONFIG           = YAML::load_file('config/config.yml')
SOURCES          = YAML::load_file('config/harvesting.yml')
SPARQL_ENDPOINT  = SPARQL::Client.new(CONFIG['rdfstore']['sparql_endpoint'])
SPARUL_ENDPOINT  = CONFIG['rdfstore']['sparul_endpoint']
DEFAULT_PREFIX   = CONFIG['rdfstore']['default_prefix']
DEFAULT_GRAPH    = CONFIG['rdfstore']['default_graph']

require './lib/rdfmodeler.rb'
require './lib/sparql_update.rb'
require './lib/string_replace.rb'

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
  
  def count_books
    query =<<-EOQ
    PREFIX bibo: <http://purl.org/ontology/bibo/>
    SELECT (COUNT(?book) as ?count) WHERE {GRAPH <#{DEFAULT_GRAPH}> { ?book a bibo:Document } }
    EOQ
    result = SPARQL_ENDPOINT.query(query).first.to_hash
    count = result[result.keys.first].value.to_i
  end
  
  def fetch_xpath_results(isbn)
    http_response = @http_persistent.request URI "#{@prefix}#{isbn}#{@suffix}#{@apikey}"
  end

  def xml_harvest(http_response, conditions)
    conditions.delete_if {|k,v| v.nil?} #delete unused conditions
    # make sure we get valid response
    if http_response.code == "200"
      xml = Nokogiri::XML(http_response.body)
      result = xml.xpath("#{conditions[:xpath]}").text
      if conditions[:gsub] then result.gsub!("#{conditions[:gsub]}", "") end
    else
      result = ""
    end
  end
  
  def rdfstore_lookup(offset, limit)
  	isbns = []
  	# query to return books without foaf:depiction
    query = <<-EOQ
    PREFIX bibo: <http://purl.org/ontology/bibo/>
    PREFIX foaf: <http://xmlns.com/foaf/0.1/>
    PREFIX local: <#{DEFAULT_PREFIX}>

    SELECT ?book ?isbn WHERE {
      GRAPH <#{DEFAULT_GRAPH}> {
        ?book bibo:isbn ?isbn ;
            a bibo:Document .
#        MINUS { ?book <#{@predicate}> ?object }
      }
    } LIMIT #{limit} OFFSET #{offset}
    EOQ
    if $debug then puts "offset: #{offset}" end
    results = SPARQL_ENDPOINT.query(query)
  end

  def sparul_insert(statements)
    statements.each do | statement |
      if $debug then puts statement.inspect end
      query = @sparul_client.insert(statement).graph(RDF::URI.new("#{DEFAULT_GRAPH}"))
      if $debug then puts query.results.inspect end
    end
  end
  
unless $offset then $offset = 0 end
book_count = count_books
if $debug then puts "book count: #{book_count.inspect}" end

@count = 0
# let's harvest!
SOURCES.each do | source, sourcevalue |
  @source = source
  @protocol = sourcevalue['protocol']
  limit = sourcevalue['limit']
  case @protocol
  when 'http'
    @prefix = sourcevalue['prefix']
    @suffix = sourcevalue['suffix']
    @apikey = sourcevalue['apikey']
    @http_persistent = Net::HTTP::Persistent.new "#{@source}"
    # next if @source == 'bokkilden'
      # loops over source, uses url and limit from yaml

    loop do    
      rdf_result = rdfstore_lookup($offset, limit)
      rdf_result.each do | solution |
        http_response = fetch_xpath_results(solution.isbn.value)
        @statements = []
        
        sourcevalue['harvest'].each do | predicate, conditions |
          obj = xml_harvest(http_response, :xpath => conditions['xpath'], :gsub => conditions['gsub'])
          unless obj.nil?
            # SPARQL UPDATE
            if conditions['datatype'] == "uri" then obj = RDF::URI.new("#{obj}") end
            @statements << RDF::Statement.new(RDF::URI.new("#{solution.book}"), RDF.module_eval("#{predicate}"), obj)
            @count += 1
          end
        sparul_insert(@statements)
        end        
      end #sourcevalue['harvest'].each
      #continue to next loop iteration
      $offset += limit
      if $recordlimit then break if @count > $recordlimit end
      break if @count >= book_count
      sleep 10 # allow source 10 secs rest between harvests ...
    end
  when 'sparql'
    puts "sparql"
  end #end case @protocol
end
p "count: #{@count}"
