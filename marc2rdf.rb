#!/usr/bin/env ruby 
# encoding: UTF-8
if RUBY_VERSION <= "1.8.7" then $KCODE = 'u' end #needed for string conversion in ruby 1.8.7
require 'rubygems'
require 'bundler/setup'

def usage(s)
    $stderr.puts(s)
    $stderr.puts("Usage: \n")
    $stderr.puts("#{File.basename($0)} -i|x input_file -o output_file [-r recordlimit]\n")
    $stderr.puts("  -c [config_file] load config file different than config/config.yml\n")    
    $stderr.puts("  -i input_file \(marc binary\)\n")
    $stderr.puts("  -x input_file \(marcxml\)\n")
    $stderr.puts("  -o output_file extension can be either .rdf (slooow) or .nt (very fast)\n")
    $stderr.puts("  -r [number] stops processing after given number of records\n")
    $stderr.puts("  -d output debug info\n")
    exit(2)
end

loop { case ARGV[0]
    when '-c' then  ARGV.shift; $config_file = ARGV.shift
    when '-i' then  ARGV.shift; $input_file  = ARGV.shift
    when '-x' then  ARGV.shift; $xmlinput_file  = ARGV.shift
    when '-o' then  ARGV.shift; $output_file = ARGV.shift
    when '-d' then  ARGV.shift; $debug = true    
    when '-r' then  ARGV.shift; $recordlimit = ARGV.shift.to_i # force integer
    when /^-/ then  usage("Unknown option: #{ARGV[0].inspect}")
    else 
      if $input_file.nil? && $xmlinput_file.nil? && $output_file.nil? then usage("Missing argument!\n") end
    break
end; }

# Defaults
$config_file = 'config/config.yml' unless $config_file

require_relative './lib/rdfmodeler.rb'

=begin
  Start processing
  - load mappingfile tags into object 'yamltags'
  - iterate outputfile into RDF::Writer
  - iterate MARC records
  - model record tag by tag, match yaml file containing RDF mappings, iterate subfields either as array or one by one
  - write processed record according to output given on command line
=end

if $xmlinput_file
  reader = MARC::XMLReader.new($xmlinput_file)
else
  reader = MARC::ForgivingReader.new($input_file)
end

i = 0

# start writer handle
RDF::Writer.open($output_file) do | writer |
=begin main block
 iterate and open writer
 insert writer block into class variable @@writer for processing records real time
 could be formal argument in ruby < 1.9 
=end
@@writer = writer

#start reading MARC records
reader.each do | record |
# limit number of records for testing purpose
i += 1
### offset and breaks for testing subset of marc records
#next unless i > 31000
#break if i > 33000
if $recordlimit then break if i > $recordlimit end

  # initiate record and set type
  rdfrecord = RDFModeler.new(record)
  rdfrecord.set_type(SparqlUpdate::CONFIG['resource']['resource_type'])
  rdfrecord.marc2rdf_convert(record)

## finally ... write processed record 
rdfrecord.write_record

end # end record loop
end # end writer loop
puts "converted records: #{i-1}"
