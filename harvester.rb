# encoding: UTF-8
if RUBY_VERSION <= "1.8.7" then $KCODE = 'u' end #needed for string conversion in ruby 1.8.7
require 'rubygems'
require 'bundler/setup'
require 'rdf'
require 'base64'
require 'nokogiri'

require_relative './lib/rdfmodeler.rb'

HARVEST_CONFIG   = YAML::load_file('config/harvesting.yml')
SOURCES          = HARVEST_CONFIG['sources']

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
      puts results
      return results
    end
  end
  
unless $offset then $offset = 0 end
book_count = Sparql::count(RDF::BIBO.Document)
puts "book count: #{book_count.inspect}" if $debug

@count = 0
$output_file = File.open($output_file, "a") if $output_file

# loops over rdfstore with limit from yaml, then source
loop do    
  # let's harvest!
  @limit  = HARVEST_CONFIG['options']['limit']
  minuses = HARVEST_CONFIG['options']['minuses']
  rdf_result = Sparql::rdfstore_lookup(:offset => $offset, :limit => @limit, :minuses => minuses, :predicate => HARVEST_CONFIG['options']['predicate'])
  
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
        http_response = fetch_xpath_results(solution.object.value)
        sourcevalue['harvest'].each do | predicate, conditions |
       
          objects = xml_harvest(http_response, :xpath => conditions['xpath'], :gsub => conditions['gsub'], :namespaces => @namespaces)
          unless objects.empty?
            if conditions['datatype'] == "uri" then objects.map! { |obj| RDF::URI("#{obj}") } end
            objects.each do | obj |
              if conditions['harvest_to'] == 'work'
                @statements << RDF::Statement.new(RDF::URI.new("#{solution.work}"), RDF.module_eval("#{predicate}"), obj)
              else
                @statements << RDF::Statement.new(RDF::URI.new("#{solution.book}"), RDF.module_eval("#{predicate}"), obj)
              end
            end
            @count += 1
          end
        end #sourcevalue['harvest'].each

      elsif @protocol == 'sparql'
        endpoint = sourcevalue['endpoint']

        query = QUERY.select.where([:s, RDF::BIBO.isbn, "#{solution.isbn.value}"],[:s, :p, :o])
        sparql_endpoint = RDF::Virtuoso::Client.new("#{endpoint}")
        #sparql_client = SPARQL::Client.new(:url => "#{endpoint}", :headers => sourcevalue['headers'])
        results = sparql_endpoint.select(query)

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
      SPARUL.sparul_insert(@statements)
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
