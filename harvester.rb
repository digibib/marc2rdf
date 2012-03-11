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
HARVEST_CONFIG   = YAML::load_file('config/harvesting.yml')
SOURCES          = HARVEST_CONFIG['sources']
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
    $stderr.puts("#{File.basename($0)} [-f output_file] [-r recordlimit] [-o offset] [-s source] [-d] \n")
    $stderr.puts("  -f [output_file] rdf output to file\n")    
    $stderr.puts("  -r [number] stops processing after given number of records\n")
    $stderr.puts("  -o [number] offset for start of harvest\n")    
    $stderr.puts("  -s [source] limit harvest to this source\n")        
    $stderr.puts("  -d debug output\n")
    exit(2)
end

loop { case ARGV[0]
    when '-f' then  ARGV.shift; $output_file = ARGV.shift
    when '-r' then  ARGV.shift; $recordlimit = ARGV.shift.to_i # force integer
    when '-o' then  ARGV.shift; $offset = ARGV.shift.to_i # force integer
    when '-s' then  ARGV.shift; $source = ARGV.shift
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
      return result
    end
  end
  
  def rdfstore_lookup(offset, limit)
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
      if $output_file then $output_file << statement.to_s + "\n" end
      query = @sparul_client.insert([statement]).graph(RDF::URI.new("#{DEFAULT_GRAPH}"))
      if $debug then puts query.inspect end
    end
  end
  
unless $offset then $offset = 0 end
book_count = count_books
if $debug then puts "book count: #{book_count.inspect}" end

@count = 0
if $output_file then $output_file = File.open($output_file, "a") end

# loops over source, uses url and limit from yaml
loop do    
  # let's harvest!
  @limit = HARVEST_CONFIG['options']['limit']
  rdf_result = rdfstore_lookup($offset, @limit)
  rdf_result.each do | solution |
    SOURCES.each do | source, sourcevalue |
      @statements = []
      # if given source on commandline, limit to this source only
      if $source then next if $source != source end
      @protocol = sourcevalue['protocol']
      if @protocol == 'http'
        @prefix = sourcevalue['prefix']
        @suffix = sourcevalue['suffix']
        @apikey = sourcevalue['apikey']
        @http_persistent = Net::HTTP::Persistent.new "#{source}"
        http_response = fetch_xpath_results(solution.isbn.value)

        sourcevalue['harvest'].each do | predicate, conditions |
          obj = xml_harvest(http_response, :xpath => conditions['xpath'], :gsub => conditions['gsub'])
          unless obj.empty?
            # SPARQL UPDATE
            if conditions['datatype'] == "uri" then obj = RDF::URI.new("#{obj}") end
            @statements << RDF::Statement.new(RDF::URI.new("#{solution.book}"), RDF.module_eval("#{predicate}"), obj)
            @count += 1
          end
        end #sourcevalue['harvest'].each

      elsif @protocol == 'sparql'
        query = <<-EOQ
        PREFIX bibo: <http://purl.org/ontology/bibo/>
        SELECT * WHERE {
          ?s bibo:isbn "#{solution.isbn.value}" ;
             ?p ?o .
        }
        EOQ
        endpoint = sourcevalue['endpoint']
        sparql_client = SPARQL::Client.new("#{endpoint}", :headers => sourcevalue['headers'])
        results = sparql_client.query(query, sourcevalue['options'])

        results.each do | statement |
          # harvest!
          sourcevalue['harvest'].each do | predicate |
            #p result[RDF.module_eval("#{predicate}")]
            if statement[:p] == RDF.module_eval("#{predicate}")
              @statements << RDF::Statement.new(RDF::URI.new("#{solution.book}"), RDF.module_eval("#{predicate}"), statement[:o])
            end
          end
        end #end results.each       

      end #end if @protocol
      sparul_insert(@statements)
    end #end SOURCES.each
  end #end rdf_result.each
  #continue to next loop iteration
  $offset += @limit
  if $recordlimit then break if @count > $recordlimit end
  break if @count >= book_count
sleep 5 # allow endpoint 5 secs rest between harvests ...
end    

p "count: #{@count}"
if $output_file then $output_file.close end
