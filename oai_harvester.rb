#!/usr/bin/env ruby 
# encoding: UTF-8
if RUBY_VERSION <= "1.8.7" then $KCODE = 'u' end #needed for string conversion in ruby 1.8.7
require 'rubygems'
require 'oai'
require 'rest_client'

require_relative './lib/rdfmodeler.rb'
require_relative './lib/sparql_update.rb'
require_relative './lib/string_replace.rb'

def usage(s)
    $stderr.puts(s)
    $stderr.puts("Usage: \n")
    $stderr.puts("#{File.basename($0)} [-f fromdate] [-r recordlimit]\n")
    $stderr.puts("  -r [number] stops processing after given number of records\n")
    $stderr.puts("  -f 'date' harvests records starting from the given date. Default is yesterday.\n")
    $stderr.puts("  -d debug output to stdout.\n")
    exit(2)
end

# Defaults
$fromdate = Date.today.prev_day.to_s

loop { case ARGV[0]
    when '-f' then  ARGV.shift; $fromdate = ARGV.shift
    when '-r' then  ARGV.shift; $recordlimit = ARGV.shift.to_i # force integer
    when '-d' then  ARGV.shift; $debug = true
    when '-h' then  usage("help")
    when /^-/ then  usage("Unknown option: #{ARGV[0].inspect}")
    else 
    break
end; }

=begin
  Start processing
  - load mappingfile tags into object 'yamltags'
  - iterate MARC records
  - model record tag by tag, match yaml file containing RDF mappings, iterate subfields either as array or one by one
  - write processed record to OAI-PMH repository given in the config file
=end

faraday = Faraday.new :request => { :open_timeout => 20, :timeout => RDFModeler::CONFIG['oai']['timeout'] } 
client = OAI::Client.new(RDFModeler::CONFIG['oai']['repository_url'], {:redirects=>RDFModeler::CONFIG['oai']['follow_redirects'], :parser=>RDFModeler::CONFIG['oai']['parser'], :timeout=>RDFModeler::CONFIG['oai']['timeout'], :debug=>true, :http => faraday})
response = client.list_records :metadata_prefix =>RDFModeler::CONFIG['oai']['format'], :from => $fromdate, :until => Date.today.to_s

# Pick out the first records
oairecords = Array.new
response.each do | oairecord |
  oairecords << oairecord
end

# If we got a resumption token we need to loop until we have all the records
while(response.resumption_token and not response.resumption_token.empty?)
  response = client.list_records(:resumption_token => response.resumption_token)
  response.each do | oairecord |
    oairecords << oairecord
  end
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
    SparqlUpdate.sparql_purge(titlenumber)
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
      rdfrecord.set_type(RDFModeler::CONFIG['resource']['resource_type'])
    
	  rdfrecord.marc2rdf_convert(record)
    # and do sparql update, preserving harvested resources
    SparqlUpdate.sparql_update(titlenumber, :preserve => RDFModeler::CONFIG['oai']['preserve_on_update'])
    
    end # end oairecord loop

  
  
  end # end oairecords.deleted?
 end # end oairecords.each
end # end writer loop
puts "modified records: #{i}"
