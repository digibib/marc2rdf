#!/usr/bin/env ruby

require 'rubygems'
require 'marc'
require 'yaml'
require 'rdf'
require 'rdf/rdfxml'
#require 'rdf/n3'
require 'rdf/ntriples'

CONFIG = YAML.load_file('config/config.yml')
MAPPINGFILE = YAML::load_file(CONFIG['mapping']['file'])

def usage(s)
    $stderr.puts(s)
    $stderr.puts("Usage: \n")
    $stderr.puts("#{File.basename($0)} -i input_file -o output_file [-r recordlimit]\n")
    $stderr.puts("  -i input_file must be marc binary\n")
    $stderr.puts("  -o output_file extension can be either .rdf (slooow) or .nt (very fast)\n")
    $stderr.puts("  -r [number] stops processing after given number of records\n")
    exit(2)
end

loop { case ARGV[0]
    when '-i':  ARGV.shift; $input_file = ARGV.shift
    when '-o':  ARGV.shift; $output_file = ARGV.shift
    when '-r':  ARGV.shift; $recordlimit = ARGV.shift.to_i
    when /^-/:  usage("Unknown option: #{ARGV[0].inspect}")
    else 
      if !$input_file || !$output_file then usage("Missing argument!\n") end
    break
end; }

# Initialize additional vocabularies we will be drawing from
module RDF
  class BIBO < RDF::Vocabulary("http://purl.org/ontology/bibo/");end
end

class RDFModeler
  attr_reader :record, :statements, :uri
  def initialize(record)
    @record = record
    construct_uri
    @statements = []
  end
    
  def construct_uri
    @uri = RDF::URI.intern(CONFIG['uri']['base'] + CONFIG['uri']['resource_path'] + CONFIG['uri']['resource_prefix'])
    id = @record[CONFIG['uri']['resource_identifier_field']]
    @uri += id.value.strip
  end

  def set_type(t)
    @statements << RDF::Statement.new(@uri, RDF.type, t)
  end
  
  def generate_uri(s, regex=nil, prefix=nil)
    if !regex.nil?
      s.gsub!(/#{regex}/, '') 
      u = RDF::URI("#{prefix}#{s}")
    else
      u = RDF::URI("#{s}")
    end
  end
  
  def assert(p, o)
    @statements << RDF::Statement.new(@uri, RDF::URI(p), o)
  end
  
  def relate(s, p, o)
    @statements << RDF::Statement.new(RDF::URI(s), p, o)
  end

  def write_record
      @statements.each do | statement |
      #p statement
        @@writer << statement
      end
  end
end

=begin
  Start processing
  - load mappingfile tags into object 'yamltags'
  - iterate outputfile into RDF::Writer
  - iterate MARC records
  - model record tag by tag, match yaml file containing RDF mappings, iterate subfields either as array or one by one
  - write processed record according to output given on command line
=end

yamltags = MAPPINGFILE['tag']
reader = MARC::ForgivingReader.new($input_file)
i = 0

# start writer handle
RDF::Writer.open($output_file) do | writer |
# insert writer block into class variable @@writer for processing records real time
# could be formal argument in ruby < 1.9 
@@writer = writer

#start reading MARC records
reader.each do | record |

# limit number of records for testing purpose
i += 1
if $recordlimit then break if i > $recordlimit end

  # initiate record and set type
  rdfrecord = RDFModeler.new(record)
  rdfrecord.set_type(RDF::BIBO.Book)

# start graph handle, one graph per record, else graph will grow too large to parse
  record.tags.each do | marctag | 
    # put all marc tag fields into array object 'marcfields' for later use
    marcfields = record.find_all { |field| field.tag == marctag }
    # start matching MARC tags against yamltags, put results in match array
    match = yamltags.select { |k,v| marctag  =~ /#{k}/ }
    # remove empty arrays - spare time parsing?
#    if !match.empty?
    
      match.each do |yamlkey,yamlvalue|

       # iterate each marc tag array object to catch multiple marc fields 
       marcfields.each do | marcfield | 
        # controlfields 001-008 don't have subfields
        unless yamlvalue['subfield']
          # do controlfields here ... to be done
        else
          
          yamlvalue['subfield'].each do | subfields | 
=begin
  here comes mapping of MARC datafields, subfield by subfield 
  subfields[0] contains subfield key
  subfields[1] contains hash of rdf mapping values from yamlfile
=end
            ## Conditions? ... to be done
            if subfields[1].has_key?('conditions')
                #p subfields[1]['conditions']
            ## Relations?
            elsif subfields[1].has_key?('relation')
               ## Multiple subfields from array? eg. ["a", "b", "c"]
               ## share same relations, but needs to be iterated for fetching right marcfield
               if subfields[0].kind_of?(Array)
                 subfields[0].each do | subfield |
                   object = "#{marcfield[subfield]}"
 
                   unless object.empty?
                     objects = []
                     if subfields[1]['object'].has_key?('split')
                       ary = object.split(subfields[1]['object']['split'])
                       ary.delete_if {|c| c.empty? }
                       ary.each { | a | objects << a }
                     else
                       objects << object
                     end
                     
                     # iterate over objects
                     objects.each do | o |
                       object_uri = rdfrecord.generate_uri(o, subfields[1]['object']['regex'], "#{subfields[1]['object']['prefix']}")
                       # first create assertion triple
                       rdfrecord.assert(subfields[1]['predicate'], object_uri)

                       ## create relation class
                       relatorclass = "#{subfields[1]['relation']['class']}"
                       rdfrecord.relate(object_uri, RDF.type, RDF::URI(relatorclass))
                     
                       # do relations have subfields? parse them too ...
                       relationsubfields = subfields[1]['relation']['subfield']
                       if relationsubfields 

                         relationsubfields.each do | relsub |
                           relobject = "#{marcfield[relsub[0]]}"
                           unless relobject.empty?
                             if relsub[1]['object']['type'] == "uri"
  
                               relobject_uri = rdfrecord.generate_uri(relobject, relsub[1]['object']['regex'], "#{relsub[1]['object']['prefix']}")
                               rdfrecord.relate(object_uri, RDF::URI(relsub[1]['predicate']), relobject_uri)
                             else
                               rdfrecord.relate(object_uri, RDF::URI(relsub[1]['predicate']), relobject)
                             end
                           end # end unless empty relobject
                         end # end relationsubfields.each
                       end # end if relationsubfields
                     end # end objects.each
                   end # end unless object.empty?
                 end # end subfields[0].each
=begin
  single subfields from yaml
=end               
               else # no subfield arrays?
                 
                 object = "#{marcfield[subfields[0]]}"
                 unless object.empty?
                   objects = []
				   if subfields[1]['object'].has_key?('split')
                     ary = object.split(subfields[1]['object']['split'])
                     ary.delete_if {|c| c.empty? }
                     ary.each { | a | objects << a }
                   else
                     objects << object
                   end
                   
                   objects.each do | o |
                     object_uri = rdfrecord.generate_uri(o, subfields[1]['object']['regex'], "#{subfields[1]['object']['prefix']}")
                     # first create assertion triple
                     rdfrecord.assert(subfields[1]['predicate'], object_uri)

                     ## create relation class
                     relatorclass = "#{subfields[1]['relation']['class']}"
                     rdfrecord.relate(object_uri, RDF.type, RDF::URI(relatorclass))
                                       
                     # do relations have subfields? parse them too ...
                     relationsubfields = subfields[1]['relation']['subfield']
                     if relationsubfields 
                       relationsubfields.each do | relsub |
                         relobject = "#{marcfield[relsub[0]]}"
                         unless relobject.empty?
                           if relsub[1]['object']['type'] == "uri"
                             relobject_uri = rdfrecord.generate_uri(relobject, relsub[1]['object']['regex'], "#{relsub[1]['object']['prefix']}")

                             rdfrecord.relate(object_uri, RDF::URI(relsub[1]['predicate']), relobject_uri)
                           else
                             rdfrecord.relate(object_uri, RDF::URI(relsub[1]['predicate']), relobject)
                           end
                         end # end unless empty relobject
                       end # end relationsubfields.each
                     end # end if relationsubfields
                   end # objects.each
                 end # end unless object.empty?
               end
            ## Straight triples
            else
              if subfields[1]['object']['type'] == "uri"
                object = "#{marcfield[subfields[0]]}"
                unless object.empty?
                  objects = []
				  if subfields[1]['object'].has_key?('split')
                    ary = object.split(subfields[1]['object']['split'])
                    ary.delete_if {|c| c.empty? }
                    ary.each { | a | objects << a }
                  else
                    objects << object
                  end                
                  objects.each do | o |
                    object_uri = rdfrecord.generate_uri(o, subfields[1]['object']['regex'], "#{subfields[1]['object']['prefix']}")
                    rdfrecord.assert("#{subfields[1]['predicate']}", object_uri)
                  end # end objects.each
                end
              else
                object = "#{marcfield[subfields[0]]}"
                unless object.empty?
                  rdfrecord.assert("#{subfields[1]['predicate']}", object)
                end
              end
            end
          end
        end # end unless yamlvalue['subfield']
       end # end marcfields.each
      end # end match.each
#    end # end if !match.empty?
  end # end record.tags.each

## finally ... write processed record 
rdfrecord.write_record

end # end record loop
end # end writer loop
