#!/usr/bin/env ruby

require 'rubygems'
require 'marc'
require 'yaml'
require 'rdf'
require 'rdf/rdfxml'
#require 'rdf/n3'
#require 'rdf/ntriples'
#require 'linkeddata' # sudo gem install linkeddata

include RDF

# quit unless our script gets two command line arguments
unless ARGV.length == 2
  puts "normarc2rdf.rb -- convert NORMARC file to RDF"
  puts "Missing input or output file!"
  puts "Usage: ruby normarc2rdf.rb InputFile.mrc OutputFile.rdf\n"
  exit
end

# our input file should be the first command line arg
input_file = ARGV[0]

# our output file should be the second command line arg
output_file = ARGV[1]

# files
mappingfile = YAML::load_file('mapping-normarc2rdf.yml')
reader = MARC::ForgivingReader.new(input_file)
#writer = RDF::Writer.new(output_file)

# reading records from a batch file


# Initialize additional vocabularies we will be drawing from
module RDF
  class BIBO < RDF::Vocabulary("http://purl.org/ontology/bibo/");end
  class RDA < RDF::Vocabulary("http://RDVocab.info/Elements/");end
  class FRBR < RDF::Vocabulary("http://purl.org/vocab/frbr/core#");end
  class OV < RDF::Vocabulary("http://open.vocab.org/terms/");end
  class PODE < RDF::Vocabulary("http://bibpode.no/terms/");end
  class XFOAF < RDF::Vocabulary("http://www.foafrealm.org/xfoaf/0.1/");end
end

graph = RDF::Graph.new
yamltags = mappingfile['tag']
i = 0

# start writer handle
RDF::Writer.open("output.rdf") do | writer |

#start reading MARC records
reader.each do | record |

# start graph handle, one graph per record, else graph will grow too large to parse
writer << RDF::Graph.new do | graph |

  record.each do | field | 
  # do controlfields first, they don't have subfields
    # start parsing MARC tags
    field.tag = case
    when field.tag == "001"
    @id = field.value.strip
    @resource = RDF::URI.new("http://redstore.deichman.no/resource/#{@id}")
    statement = RDF::Statement.new({
    :subject   => @resource,
    :predicate => RDF.type,
    :object    => RDF::BIBO.Document,
    })
    graph << statement
  # end controlfield
    when field.tag == "007"
    when field.tag == "008" # language, to be done
    
    # parse the datafields agains yaml file
    else
      yamltags.each do | yamltag, yamlsubfield |
        # do marc vs yaml tag match with regex
        if field.tag =~ /#{yamltag}/ 
          yamlsubfield['subfield'].each do | yamlkey, yamlvalue |
          ### here comes the mapping ###
            yamlvalue = case
          # conditionals?
            when yamlvalue['conditions']
          # to be done ...
          #    puts "condition: #{yamlvalue["conditions"]}"
          
          # generate relations if they exist
            when yamlvalue['relation']
              @relation_uri = RDF::URI.new("http://redstore.deichman.no/relation/#{field[yamlkey]}")
              # add relation to document graph first, then add relations to graph
                statement = RDF::Statement.new({
                :subject   => @resource,
                :predicate => RDF::URI(yamlvalue['predicate']),
                :object    => @relation_uri,
                })
                graph << statement       
              # more than one subfields in relation?
              if yamlvalue['relation']['subfield']
                yamlvalue['relation']['subfield'].each do | relationkey, relationvalue |
                  if field[relationkey]
                    statement = RDF::Statement.new({
                    :subject   => @relation_uri,
                    :predicate => RDF::URI(relationvalue['predicate']),
                    :object    => RDF::URI(field[relationkey]),
                    })
                    graph << statement
                  end
                end
              elsif yamlvalue['relation']['object'] && yamlvalue['relation']['object']['type'] == "uri"
                statement = RDF::Statement.new({
                :subject   => @relation_uri,
                :predicate => RDF.type,
                :object    => RDF::URI(yamlvalue['relation']['class']),
                })
                graph << statement
              elsif 
                statement = RDF::Statement.new({
                :subject   => @relation_uri,
                :predicate => RDF.type,
                :object    => RDF::URI(yamlvalue['relation']['class']),
                })
                graph << statement
              end
          # generate statements if yaml and marc subfields coexist
            else
            #p yamlvalue
              if yamlvalue['object']['type'] == "uri"
                statement = RDF::Statement.new({
                :subject   => @resource,
                :predicate => RDF::URI(yamlvalue['predicate']),
                :object    => RDF::URI(field[yamlkey]),
                })
                graph << statement
              elsif yamlvalue['object']['type'] == "literal"
                statement = RDF::Statement.new({
                :subject   => @resource,
                :predicate => RDF::URI(yamlvalue['predicate']),
                :object    => "#{field[yamlkey]}",
                })
                graph << statement
              end

             # end match marc vs yaml subfield
              # p field[yamlkey]
            end # end case yamlvalue ... when
          end
        end
      end
      
    end # end case field.tag 
    
  end # end match field.tag vs yamltag

end # end graph loop

# do only certain number of records for testing
i += 1
break if i == 100
end # end record loop
end # end writer loop
