#!/usr/bin/env ruby 
# encoding: UTF-8
require 'bundler/setup'
require 'builder'
require 'rubygems'
require 'yaml'
require 'oai'
require 'marc'
require 'rdf'
require 'rdf/rdfxml'
require 'rdf/ntriples'
require 'rest_client'

CONFIG = YAML::load_file('config/config.yml')
MAPPINGFILE = YAML::load_file(CONFIG['mapping']['file'])

require './lib/rdfmodeler.rb'
require './lib/sparql_update.rb'

def usage(s)
    $stderr.puts(s)
    $stderr.puts("Usage: \n")
    $stderr.puts("#{File.basename($0)} -o output_file [-r recordlimit]\n")
    $stderr.puts("  -o output_file extension can be either .rdf (slooow) or .nt (very fast)\n")
    $stderr.puts("  -r [number] stops processing after given number of records\n")
    exit(2)
end

loop { case ARGV[0]
    when '-o' then  ARGV.shift; $output_file = ARGV.shift
    when '-r' then  ARGV.shift; $recordlimit = ARGV.shift.to_i # force integer
    when /^-/ then  usage("Unknown option: #{ARGV[0].inspect}")
    else 
    break
end; }

=begin
  Start processing
  - load mappingfile tags into object 'yamltags'
  - iterate outputfile into RDF::Writer
  - iterate MARC records
  - model record tag by tag, match yaml file containing RDF mappings, iterate subfields either as array or one by one
  - write processed record according to output given on command line
=end

@@yamltags = MAPPINGFILE['tags']
client = OAI::Client.new(CONFIG['oai']['repository_url'], {:redirects=>CONFIG['oai']['follow_redirects'], :parser=>CONFIG['oai']['parser'], :timeout=>CONFIG['oai']['timeout'], :debug=>true})
oairecords = client.list_records :metadata_prefix =>CONFIG['oai']['format'], :from => Date.today.prev_day.to_s, :until => Date.today.to_s

i = 0

# start writer handle
RDF::Writer.open($output_file) do | writer |
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
    RestClient.sparql_delete(titlenumber)
    next  
  else 
    puts "modified: #{titlenumber}"
    ## read metadata into MARCXML object
    xmlreader = MARC::XMLReader.new(StringIO.new(oairecord.metadata.to_s))

    #start parsing MARC records
    xmlreader.each do | record |
    # limit number of records for testing purpose
    i += 1
    ### offset and breaks for testing subset of marc records
    #next unless i > 31000
    #break if i > 33000
    if $recordlimit then break if i > $recordlimit end
    
      # initiate record and set type
      rdfrecord = RDFModeler.new(record)
      rdfrecord.set_type(CONFIG['resource']['resource_type'])
    
	  rdfrecord.marc2rdf_convert(record)
    
    ## finally ... write processed record if output file stated
    if $output_file then rdfrecord.write_record end
    
    # and do sparql update
    RestClient.sparql_insert(titlenumber)
    
    end # end oairecord loop

  
  
  end # end oairecords.deleted?
 end # end oairecords.each
end # end writer loop
puts "converted records: #{i-1}"
