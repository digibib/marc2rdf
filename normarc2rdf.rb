#!/usr/bin/env ruby 
# encoding: UTF-8

require 'rubygems'
require 'marc'
require 'yaml'
require 'rdf'
require 'rdf/rdfxml'
#require 'rdf/n3'
require 'rdf/ntriples'

CONFIG = YAML::load_file('config/config.yml')
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
    when '-i' then  ARGV.shift; $input_file  = ARGV.shift
    when '-o' then  ARGV.shift; $output_file = ARGV.shift
    when '-r' then  ARGV.shift; $recordlimit = ARGV.shift.to_i # force integer
    when /^-/ then  usage("Unknown option: #{ARGV[0].inspect}")
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
  
  def generate_uri(s, prefix=nil)
    u = RDF::URI("#{prefix}#{s}")
  end
  
  def generate_objects(o, options={})
=begin
 function to split and clean object(s) by optional parameters fed from yaml file
   :regex_split => regex split condition, eg. ", *" - split by comma and space
   :regex_replace => regex characters to replace, eg. "Å|Ø|Æ|\ |" mapped against hash substitutes in yaml file
   :regex_strip => regex match to strip away
   :substr_offset => string slice by position, eg. - substr_offset: 34 - get string from position 34
   :substr_length => string slice length
   regex_split takes precedence, then regex_replace and finally regex_strip to remove disallowed characters
   TODO: function to combine fields
=end
  objects = []
  subs = MAPPINGFILE['substitutes']
    if options[:regex_split]
      ary = o.split(/#{options[:regex_split]}/)
      ary.delete_if {|c| c.empty? }
      if options[:regex_replace]
        ary_replaced = []
        ary.each { |a| ary_replaced << a.gsub(/#{options[:regex_replace]}/) { |match| subs[match] } }
        if options[:regex_strip]
          ary_replaced.each { |a| objects << a.gsub(/#{options[:regex_strip]}/, '') }
        else
          ary_replaced.each { |a| objects << a }
        end
      elsif options[:regex_strip]
        ary.each { |a| objects << a.gsub(/#{options[:regex_strip]}/, '') }
      else
        objects << ary.each { |a| objects << a }
      end
      
    elsif options[:regex_replace]
      o.gsub!(/#{options[:regex_replace]}/) { |match| subs[match] }
      if options[:regex_strip]
        o.gsub!(/#{options[:regex_strip]}/, '')
      end
      objects << o
      
    elsif options[:regex_strip]
      objects << o.gsub(/#{options[:regex_strip]}/, '')
    elsif options[:substr_offset]
      objects << o.slice(options[:substr_offset],options[:substr_length])
    else
      objects << o
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

yamltags = MAPPINGFILE['tags']
reader = MARC::ForgivingReader.new($input_file)
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
if $recordlimit then break if i > $recordlimit end

  # initiate record and set type
  rdfrecord = RDFModeler.new(record)
  rdfrecord.set_type(RDF::URI(CONFIG['uri']['resource_type']))

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

        # controlfields 001-009 don't have subfields
        unless yamlvalue.has_key?('subfield')
          # do controlfields here ... to be done
          object = "#{marcfield.value}"
          unless object.empty?
            yamlvalue.each do | key,value |
              objects = rdfrecord.generate_objects(object, :regex_split => value['object']['regex_split'], :regex_replace => value['object']['regex_replace'], :regex_strip => value['object']['regex_strip'], :substr_offset => value['object']['substr_offset'], :substr_length => value['object']['substr_length'])
              objects.each do | o |
                unless value['object']['datatype'] == "literal"
                  object_uri = rdfrecord.generate_uri(o, "#{value['object']['prefix']}")
                  # first create assertion triple
                  rdfrecord.assert(value['predicate'], object_uri)
                  if value.has_key?('relation')
                    ## create relation class
                    relatorclass = "#{value['relation']['class']}"
                    rdfrecord.relate(object_uri, RDF.type, RDF::URI(relatorclass))
                  end # end if relation
                else # literal
                  rdfrecord.assert(value['predicate'], RDF::Literal("#{o}"))
                end
              end # end objects.each
            end # end yamlvalue.each    
          end # end unless object.empty?

        else
          
          yamlvalue['subfield'].each do | subfields | 
=begin
  here comes mapping of MARC datafields, subfield by subfield 
  subfields[0] contains subfield key
  subfields[1] contains hash of rdf mapping values from yamlfile
=end
            ####
            ## CONDITIONS: creates predicate from hash array of "match" => "replacement"
            ## put predicate in @predicate variable for later use
            ####
            if subfields[1].has_key?('conditions')
              @predicate = ''
              subfields[1]['conditions'].each do | key,value |
                m = "#{marcfield[key]}"
                unless m.empty?
                  @predicate = m.gsub(/[\W]+/, '').downcase
                  @predicate.gsub!(/#{value['orig']}/) { |match| value['subs'][match] }
                else
                  @predicate = value['default']
                end
              end
            else
              @predicate = subfields[1]['predicate']
            end   
            ####
			## RELATIONS: make class and create relations from subfields
            ####
            if subfields[1].has_key?('relation')
               ####
               ## Multiple subfields from array? eg. ["a", "b", "c"]
               ## share same relations, but needs to be iterated to fetch right marcfield
               ####
               if subfields[0].kind_of?(Array)
                 subfields[0].each do | subfield |
                   object = "#{marcfield[subfield]}"
                   unless object.empty?
                     objects = rdfrecord.generate_objects(object, :regex_split => subfields[1]['object']['regex_split'], :regex_replace => subfields[1]['object']['regex_replace'], :regex_strip => subfields[1]['object']['regex_strip'], :substr_offset => subfields[1]['object']['substr_offset'], :substr_length => subfields[1]['object']['substr_length'])
                     # iterate over objects
                     objects.each do | o |
                       object_uri = rdfrecord.generate_uri(o, "#{subfields[1]['object']['prefix']}")
                       # first create assertion triple
                         rdfrecord.assert(@predicate, object_uri)

                       ## create relation class
                       relatorclass = "#{subfields[1]['relation']['class']}"
                       rdfrecord.relate(object_uri, RDF.type, RDF::URI(relatorclass))
                     
                       # do relations have subfields? parse them too ...
                       relationsubfields = subfields[1]['relation']['subfield']
                       if relationsubfields 
                         relationsubfields.each do | relsub |
                           relobject = "#{marcfield[relsub[0]]}"
                           unless relobject.empty?
                             relobjects = rdfrecord.generate_objects(relobject, :regex_split => relsub[1]['object']['regex_split'], :regex_replace => relsub[1]['object']['regex_replace'], :regex_strip => relsub[1]['object']['regex_strip'], :substr_offset => relsub[1]['object']['substr_offset'], :substr_length => relsub[1]['object']['substr_length'])
                             
                             relobjects.each do | ro |
                               if relsub[1]['object']['datatype'] == "uri"
  
                                 relobject_uri = rdfrecord.generate_uri(ro, "#{relsub[1]['object']['prefix']}")
                                 rdfrecord.relate(object_uri, RDF::URI(relsub[1]['predicate']), RDF::URI(relobject_uri))
                               else
                                 rdfrecord.relate(object_uri, RDF::URI(relsub[1]['predicate']), RDF::Literal("#{ro}", :language => relsub[1]['object']['lang']))
                               end
                             end # end relobjects.each
                           end # end unless empty relobject
                         end # end relationsubfields.each
                       end # end if relationsubfields
                     end # end objects.each
                   end # end unless object.empty?
                 end # end subfields[0].each
=begin
  parse single subfields from yaml
=end               
               else # no subfield arrays?
                 object = "#{marcfield[subfields[0]]}"
                 unless object.empty?
                   objects = rdfrecord.generate_objects(object, :regex_split => subfields[1]['object']['regex_split'], :regex_replace => subfields[1]['object']['regex_replace'], :regex_strip => subfields[1]['object']['regex_strip'], :substr_offset => subfields[1]['object']['substr_offset'], :substr_length => subfields[1]['object']['substr_length'])
                   objects.each do | o |
                     object_uri = rdfrecord.generate_uri(o, "#{subfields[1]['object']['prefix']}")
                     # first create assertion triple
                         rdfrecord.assert(@predicate, object_uri)

                     ## create relation class
                     relatorclass = "#{subfields[1]['relation']['class']}"
                     rdfrecord.relate(object_uri, RDF.type, RDF::URI(relatorclass))
                                       
                     # do relations have subfields? parse them too ...
                     relationsubfields = subfields[1]['relation']['subfield']
                     if relationsubfields 
                       relationsubfields.each do | relsub |
                         relobject = "#{marcfield[relsub[0]]}"
                         unless relobject.empty?
                           relobjects = rdfrecord.generate_objects(relobject, :regex_split => relsub[1]['object']['regex_split'], :regex_replace => relsub[1]['object']['regex_replace'], :regex_strip => relsub[1]['object']['regex_strip'], :substr_offset => relsub[1]['object']['substr_offset'], :substr_length => relsub[1]['object']['substr_length'])
                           relobjects.each do | ro |
                             if relsub[1]['object']['datatype'] == "uri"
                               relobject_uri = rdfrecord.generate_uri(ro, "#{relsub[1]['object']['prefix']}")

                               rdfrecord.relate(object_uri, RDF::URI(relsub[1]['predicate']), RDF::URI(relobject_uri))
                             else
                               rdfrecord.relate(object_uri, RDF::URI(relsub[1]['predicate']), RDF::Literal("#{ro}", :language => relsub[1]['object']['lang']))
                             end
                           end # relobjects.each
                         end # end unless empty relobject
                       end # end relationsubfields.each
                     end # end if relationsubfields
                   end # objects.each
                 end # end unless object.empty?
               end
=begin
 parse straight triples
 no relations
=end
            else
              if subfields[0].kind_of?(Array)
                subfields[0].each do | subfield |
                  object = "#{marcfield[subfield]}"
                  unless object.empty?
                    objects = rdfrecord.generate_objects(object, :regex_split => subfields[1]['object']['regex_split'], :regex_replace => subfields[1]['object']['regex_replace'], :regex_strip => subfields[1]['object']['regex_strip'], :substr_offset => subfields[1]['object']['substr_offset'], :substr_length => subfields[1]['object']['substr_length'])
                    objects.each do | o |  
                      if subfields[1]['object']['datatype'] == "uri"
                        object_uri = rdfrecord.generate_uri(o, "#{subfields[1]['object']['prefix']}")
                        rdfrecord.assert(@predicate, RDF::URI(object_uri))
                      elsif subfields[1]['object']['datatype'] == "integer"
                        rdfrecord.assert(@predicate, RDF::Literal("#{o}", :datatype => RDF::XSD.integer))
                      elsif subfields[1]['object']['datatype'] == "float"
                        rdfrecord.assert(@predicate, RDF::Literal("#{o}", :datatype => RDF::XSD.float))
                      else # literal
                        rdfrecord.assert(@predicate, RDF::Literal("#{o}", :language => subfields[1]['object']['lang']))
                      end # end if subfield
                    end # end objects.each do | o |
                  end # end unless object.empty?   
                end # end subfields[0].each
              else
                object = "#{marcfield[subfields[0]]}"
                unless object.empty?
                  objects = rdfrecord.generate_objects(object, :regex_split => subfields[1]['object']['regex_split'], :regex_replace => subfields[1]['object']['regex_replace'], :regex_strip => subfields[1]['object']['regex_strip'], :substr_offset => subfields[1]['object']['substr_offset'], :substr_length => subfields[1]['object']['substr_length'])
                  objects.each do | o |            
                    if subfields[1]['object']['datatype'] == "uri"
                      object_uri = rdfrecord.generate_uri(o, "#{subfields[1]['object']['prefix']}")
                      rdfrecord.assert(@predicate, RDF::URI(object_uri))
                    elsif subfields[1]['object']['datatype'] == "integer"
                      rdfrecord.assert(@predicate, RDF::Literal("#{o}", :datatype => RDF::XSD.integer))
                    elsif subfields[1]['object']['datatype'] == "float"
                      rdfrecord.assert(@predicate, RDF::Literal("#{o}", :datatype => RDF::XSD.float))
                    else # literal
                      rdfrecord.assert(@predicate, RDF::Literal("#{o}", :language => subfields[1]['object']['lang']))
                    end # end if subfields
                  end # end objects.each do | o |
                end # end unless object.empty?           
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
puts "converted records: #{i-1}"
