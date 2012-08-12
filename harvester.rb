# encoding: UTF-8
if RUBY_VERSION <= "1.8.7" then $KCODE = 'u' end #needed for string conversion in ruby 1.8.7
require 'rubygems'
require 'bundler/setup'
require 'base64'
require 'nokogiri'

require_relative './lib/rdfmodeler.rb'

HARVEST_CONFIG   = YAML::load_file('config/harvesting.yml')
SOURCES          = HARVEST_CONFIG['sources']
SPARQL_ENDPOINT  = RDFModeler::CONFIG['rdfstore']['sparql_endpoint']
SPARUL_ENDPOINT  = RDFModeler::CONFIG['rdfstore']['sparul_endpoint']
DEFAULT_PREFIX   = RDFModeler::CONFIG['rdfstore']['default_prefix']
DEFAULT_GRAPH    = RDF::URI(RDFModeler::CONFIG['rdfstore']['default_graph'])

@username    = RDFModeler::CONFIG['rdfstore']['username']
@password    = RDFModeler::CONFIG['rdfstore']['password']
@auth_method = RDFModeler::CONFIG['rdfstore']['auth_method']

REPO = RDF::Virtuoso::Repository.new(SPARUL_ENDPOINT, :username => @username, :password => @password, :auth_method => @auth_method)
QUERY  = RDF::Virtuoso::Query

def usage(s)
    $stderr.puts(s)
    $stderr.puts("Usage: \n")
    $stderr.puts("#{File.basename($0)} [-f output_file] [-r recordlimit] [-o offset] [-s source] [-d] \n")
    $stderr.puts("  -f [output_file] rdf output to file\n") 
    $stderr.puts("  -r [number] stops processing after given number of records\n")
    $stderr.puts("  -o [number] offset for start of harvest\n")    
    $stderr.puts("  -s [source] limit harvest to this source\n")        
    $stderr.puts("  -d debug output\n")
    $stderr.puts("  -i insert triples directly\n")    
    exit(2)
end

loop { case ARGV[0]
    when '-f' then  ARGV.shift; $output_file = ARGV.shift
    when '-r' then  ARGV.shift; $recordlimit = ARGV.shift.to_i # force integer
    when '-o' then  ARGV.shift; $offset = ARGV.shift.to_i # force integer
    when '-s' then  ARGV.shift; $source = ARGV.shift
    when '-d' then  ARGV.shift; $debug = true
    when '-i' then  ARGV.shift; $insert = true
    when /^-/ then  usage("Unknown option: #{ARGV[0].inspect}")
    else 
    break
end; }
  
  def count_books
    query    = QUERY.select.where([:book, RDF.type, RDF::BIBO.Document]).count(:book).graph(DEFAULT_GRAPH)
    puts query.to_s if $debug
    solutions = REPO.select(query)
    count = solutions.first[:count].to_i
  end
  
  def fetch_xpath_results(isbn)
    http_response = @http_persistent.request URI "#{@prefix}#{isbn}#{@suffix}#{@apikey}"
  end

  def xml_harvest(http_response, conditions)
    conditions.delete_if {|k,v| v.nil?} #delete unused conditions
    # make sure we get valid response
    if http_response.code == "200"
      xml = Nokogiri::XML(http_response.body)
      results = []
      xml.xpath("#{conditions[:xpath]}", conditions[:namespaces]).each { | elem | results << elem.text }
      if conditions[:gsub]
        results.each { |result| result.gsub!("#{conditions[:gsub]}", "") }
      end
      return results
    end
  end
  
  def rdfstore_lookup(offset, limit)

    if $debug then puts "offset: #{offset}" end
    prefixes = RDF::Virtuoso::Prefixes.new bibo: "http://purl.org/ontology/bibo/", foaf: "http://xmlns.com/foaf/0.1/", local: "#{DEFAULT_PREFIX}"
    #minuses = [:book, RDF::FOAF.depiction, :object]
    query = QUERY.select(:book, :isbn).where([:book, RDF::type, RDF::BIBO.Document],[:book, RDF::BIBO.isbn, :isbn]).prefixes(prefixes).offset(offset).limit(limit)
    puts query.to_s if $debug
    
    result = REPO.select(query)
  end

  def sparul_insert(statements)
    unless statements.empty?
      query = QUERY.insert_data(statements).graph(DEFAULT_GRAPH)
      puts query.to_s if $debug
      #puts statements.each { |s| s.to_s } if $debug
      statements.each {|statement| $output_file << RDF::NTriples.serialize(statement) } if $output_file
      result = REPO.insert_data(query) if $insert
    end
  end
  
unless $offset then $offset = 0 end
book_count = count_books
puts "book count: #{book_count.inspect}" if $debug

@count = 0
$output_file = File.open($output_file, "a") if $output_file

# loops over rdfstore with limit from yaml, then source
loop do    
  # let's harvest!
  @limit = HARVEST_CONFIG['options']['limit']
  rdf_result = rdfstore_lookup($offset, @limit)
  # iterate SPARQL results
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
        @namespaces = sourcevalue['namespaces']
        @http_persistent = Net::HTTP::Persistent.new "#{source}"
        http_response = fetch_xpath_results(solution.isbn.value)
        sourcevalue['harvest'].each do | predicate, conditions |
       
          objects = xml_harvest(http_response, :xpath => conditions['xpath'], :gsub => conditions['gsub'], :namespaces => @namespaces)
          unless objects.empty?
            if conditions['datatype'] == "uri" then objects.each { |obj| obj = RDF::URI.new("#{obj}") } end
            objects.each do | obj |
              @statements << RDF::Statement.new(RDF::URI.new("#{solution.book}"), RDF.module_eval("#{predicate}"), obj)
            end
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
        REPO = RDF::Virtuoso::Client.new(@sparul_endpoint, :username => @username, :password => @password, :auth_method => @auth_method)
        sparql_client = SPARQL::Client.new(:url => "#{endpoint}", :headers => sourcevalue['headers'])
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
$output_file.close if $output_file
