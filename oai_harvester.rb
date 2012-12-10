#!/usr/bin/env ruby 
# encoding: UTF-8
if RUBY_VERSION <= "1.8.7" then $KCODE = 'u' end #needed for string conversion in ruby 1.8.7
require 'rubygems'
require 'bundler/setup'
require 'oai'

def usage(s)
    $stderr.puts(s)
    $stderr.puts("Usage: \n")
    $stderr.puts("#{File.basename($0)} [-f fromdate] [-r recordlimit]\n")
    $stderr.puts("  -c [config_file] load config file different than config/config.yml\n")    
    $stderr.puts("  -r [number] stops processing after given number of records\n")
    $stderr.puts("  -f 'date' harvests records starting from the given date. Default is yesterday.\n")
    $stderr.puts("  -d debug output to stdout.\n")
    $stderr.puts("  -i [input filename] harvest to catalogue from file.\n")
    $stderr.puts("  -o [output filename] output to file instead of harvest directly to catalogue.\n")
    exit(2)
end

loop { case ARGV[0]
    when '-f' then  ARGV.shift; $fromdate = ARGV.shift
    when '-c' then  ARGV.shift; $config_file = ARGV.shift
    when '-r' then  ARGV.shift; $recordlimit = ARGV.shift.to_i # force integer
    when '-d' then  ARGV.shift; $debug = true
    when '-i' then  ARGV.shift; $input_file = ARGV.shift
    when '-o' then  ARGV.shift; $output_file = ARGV.shift    
    when '-h' then  usage("help")
    when /^-/ then  usage("Unknown option: #{ARGV[0].inspect}")
    else 
    break
end; }

# Defaults
$fromdate = Date.today.prev_day.to_s unless $fromdate
$config_file = 'config/config.yml' unless $config_file

require_relative './lib/rdfmodeler.rb'

=begin
  Start processing
  - load mappingfile tags into object 'yamltags'
  - iterate MARC records
  - model record tag by tag, match yaml file containing RDF mappings, iterate subfields either as array or one by one
  - write processed record to OAI-PMH repository given in the config file
=end


# unless input file is given, start http harvesting
unless $input_file
  faraday = Faraday.new :request => { :open_timeout => 20, :timeout => SparqlUpdate::CONFIG['oai']['timeout'] } 
  client = OAI::Client.new(SparqlUpdate::CONFIG['oai']['repository_url'], {:redirects => SparqlUpdate::CONFIG['oai']['follow_redirects'], :parser => SparqlUpdate::CONFIG['oai']['parser'], :timeout => SparqlUpdate::CONFIG['oai']['timeout'], :debug => true, :http => faraday})
  response = client.list_records :metadata_prefix => SparqlUpdate::CONFIG['oai']['format'], :from => $fromdate, :until => Date.today.to_s
  
  num_records = 0
  
  # Pick out the first records
  oairecords = Array.new
  response.each do | oairecord |
    num_records += 1
    if $output_file
      File.open($output_file, 'a') {|f| f << oairecord.metadata.to_s } 
    else
      oairecords << oairecord
    end
  end
  
  # If we got a resumption token we need to loop until we have all the records
  while(response.resumption_token and not response.resumption_token.empty?)
    response = client.list_records(:resumption_token => response.resumption_token)
    # send to file or add to oairecords object
    response.each do | oairecord |
      num_records += 1
      if $output_file
        File.open($output_file, 'a') {|f| f << oairecord.metadata.to_s } 
      else
        oairecords << oairecord
      end
    end
  end
  
  # exit when done if redirected to output_file
  abort("harvested #{num_records}") if $output_file

end

i = 0

# start writer handle
RDF::Writer.for(:ntriples).buffer do |writer|
=begin main block
 iterate and open writer
 insert writer block into class variable @@writer for processing records real time
 could be formal argument in ruby < 1.9 
=end
@@writer = writer
  if $input_file # harvest from previously dumped output file 
    xmlreader = MARC::XMLReader.new(StringIO.new(File.open($input_file, 'r') {|f| f.read } ))
    xmlreader.each do | record |
      i += 1    
      # limit number of records for testing purpose
      if $recordlimit then break if i > $recordlimit end
      titlenumber = "#{record['001'].value}"
      # initiate record and set type
      rdfrecord = RDFModeler.new(record)
      rdfrecord.set_type(rdfrecord::config['resource']['resource_type'])
      
      rdfrecord.marc2rdf_convert(record)
      # and do sparql update, preserving harvested resources
      OAIUpdate.sparql_update(titlenumber, :preserve => rdfrecord::config['oai']['preserve_on_update'])
    end # end oairecord loop

  else # process harvested records
    oairecords.each do | oairecord |
      i += 1
      ### offset and breaks for testing subset of marc records
      #next unless i > 31000
      #break if i > 33000
      if $recordlimit then break if i > $recordlimit end
    
      ## OAI SPECIFIC PARSING ##
      titlenumber = oairecord.header.identifier.split(':').last
    
      ## deleted record? ##
      #if oairecord.header.status == "deleted" 
      if oairecord.deleted?
        puts "deleted: #{titlenumber}"
        OAIUpdate.sparql_purge(titlenumber)
        next # deleted records have no metadata in oai
      else 
        puts "modified: #{titlenumber}"
        ## read metadata into MARCXML object
        xmlreader = MARC::XMLReader.new(StringIO.new(oairecord.metadata.to_s))
    
        #start parsing MARC records
        xmlreader.each do | record |

          # limit number of records for testing purpose
          if $recordlimit then break if i > $recordlimit end
      
          # initiate record and set type
          rdfrecord = RDFModeler.new(record)
          rdfrecord.set_type(rdfrecord::config['resource']['resource_type'])
      
          rdfrecord.marc2rdf_convert(record)
          # and do sparql update, preserving harvested resources
          OAIUpdate.sparql_update(titlenumber, :preserve => rdfrecord::config['oai']['preserve_on_update'])
        
        end # end oairecord loop
      end # end oairecords.deleted?
    end # end oairecords.each
  end # end if $input_file
end # end writer loop
puts "modified records: #{i}"
