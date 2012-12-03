require 'rubygems'
require 'bundler/setup'
require 'marc'
require 'yaml'
require 'rdf'
require 'rdf/rdfxml'
require 'rdf/n3'
require 'rdf/ntriples'

require_relative './vocabularies.rb'
require_relative '../db/model.rb'
require_relative './sparql_update.rb'
require_relative './sparql.rb'
require_relative './string_replace.rb'

class RDFModeler
  attr_reader :record, :statements, :uri, :tags
  
  def initialize(record)
    # load settings and mapping
    settings   = YAML::load_file('config/settings.yml')
    mapping    = YAML::load_file(File.open( File.join(File.dirname(__FILE__), '../db/mapping/', settings['files']['mapping_filename']) ) )
    repository = YAML::load_file(File.open( File.join(File.dirname(__FILE__), '../db/repository/', settings['files']['repository_filename']) ) )

    # populate class attributes
    @record = record
    @uri    = RDF::URI.intern(repository['resource']['base'] + repository['resource']['resource_path'] + repository['resource']['resource_prefix'])
    id      = @record[repository['resource']['resource_identifier_field']]
    @uri   += id.value.to_i    
    @statements = []
    @tags   = mapping['tags']
  end
    
  def set_type(t)
    @statements << RDF::Statement.new(@uri, RDF.type, RDF.module_eval("#{t}"))
  end
  
  def generate_uri(s, prefix=nil)
    u = RDF::URI("#{prefix}#{s}")
  end
  
  def generate_objects(o, options)
=begin
 function to split and clean object(s) by optional parameters fed from yaml file
 options are:
   :marcfield => full marcfield object to use e.g. in :combine
   :regex_split => regex split condition, eg. ", *" - split by comma and space
   :urlize => non-ascii character replacement, alternatively with :downcase, :convert_chars and :regex
   :downcase => true or false (default) 
   :convert_spaces => default '_'
   :regexp => default /[^-_A-Za-z0-9]/
   :regex_strip => regex match to strip away
   :regex_substitute => hash of 'orig', 'subs', and 'default' to map object substitutions - read into 'regex_subs'
   :substr_offset => string slice by position, eg. - substr_offset: 34 - get string from position 34
   :substr_length => string slice length
   :combine => combine field with one or more others
   :combinestring => string to combine field with
   regex_split takes precedence, then urlize and finally regex_strip to remove disallowed characters
=end

  regex_subs = options[:regex_substitute] || nil
# remove nil options
  options.delete_if {|k,v| v.nil?}

# make object array in any case
  generated_objects = []
  
  # substring must be used on whole marcfield
    if options.has_key?(:substr_offset)
      generated_objects << o.slice(options[:substr_offset],options[:substr_length])
      generated_objects.delete_if {|a| a.nil? } # needed to avoid nil-errors on invalid 008 tags
      generated_objects.delete_if {|a| a.strip.empty? }
    elsif options.has_key?(:regex_split)
      generated_objects = o.split(/#{options[:regex_split]}/)
      generated_objects.delete_if {|c| c.empty? }
    else
      generated_objects << o
    end

    if options.has_key?(:regex_substitute)
      generated_objects.collect! do |obj|
        obj = obj.gsub(/[\W]+/, '').downcase
        obj.scan(/#{regex_subs['orig']}/) do |match| 
          if match then obj = regex_subs['subs'][match] else obj = regex_subs['default'] end
        end
      obj # needed to make sure obj is returned, not match
      end
    end 

    if options.has_key?(:combine)
      generated_objects.collect! do | obj |
        obj2 = []
        options[:combine].each do |combine|
          options[:marcfield].each do |mrc|
            obj2 << mrc.value if combine == mrc.code
          end
        end
        obj2.delete_if {|d| d.nil? }
        obj = obj2.join(options[:combinestring])
      end
    end

    if options.has_key?(:urlize)
      downcase = options[:downcase] || false
      convert_spaces = options[:convert_spaces] || true
      regexp = options[:regexp] || /[^-_A-Za-z0-9]/

      generated_objects.collect! do |obj| 
        obj.urlize({:downcase => downcase, :convert_spaces => convert_spaces, :regexp => regexp})
      end
    end
    
    if options.has_key?(:regex_strip)
      generated_objects.collect! { |obj| obj.gsub(/#{options[:regex_strip]}/, '') }
    end
  
  #puts generated_objects if $debug
  return generated_objects
  end
  
  def assert(p, o)
    unless p.empty? || o.nil?
      @statements << RDF::Statement.new(@uri, RDF.module_eval("#{p}"), o)
    end
  end
  
  def relate(s, p, o)
    unless p.nil? || s.nil? || o.nil?
      @statements << RDF::Statement.new(RDF::URI(s), p, o)
    end
  end

  def write_record
      @statements.each do | statement |
      #p statement
        @@writer << statement
      end
  end
  
  def marc2rdf_convert_record(record)
  # start graph handle, one graph per record, else graph will grow too large to parse
  record.tags.each do | marctag | 
    # put all marc tag fields into array object 'marcfields' for later use
    marcfields = record.find_all { |field| field.tag == marctag }
    # start matching MARC tags against @tags from mapping, put results in match array
    match = @tags.select { |k,v| marctag  =~ /#{k}/ }
    match.each do |yamlkey,yamlvalue|
    # iterate each marc tag array object to catch multiple marc fields 
      marcfields.each do | marcfield | 

        # controlfields 001-009 don't have subfields
        unless yamlvalue.has_key?('subfield')
          # do controlfields here 
          marc_object = "#{marcfield.value}"
          unless marc_object.strip.empty?
            yamlvalue.each do | key,value |
              objects = generate_objects(marc_object, :marcfield => marcfield, :regex_split => value['object']['regex_split'], :urlize => value['object']['urlize'], :regex_strip => value['object']['regex_strip'], :regex_substitute => value['object']['regex_substitute'], :substr_offset => value['object']['substr_offset'], :substr_length => value['object']['substr_length'], :combine => value['object']['combine'], :combinestring => value['object']['combinestring'], :downcase => value['object']['downcase'])
              unless objects.empty?
                objects.each do | o |
                  unless o.strip.empty?
                    unless value['object']['datatype'] == "literal"
                      object_uri = generate_uri(o, "#{value['object']['prefix']}")
                      # first create assertion triple
                      assert("#{value['predicate']}", object_uri)
                      #assert(value['predicate'], object_uri)
                      if value.has_key?('relation')
                        ## create relation class
                        relatorclass = "#{value['relation']['class']}"
                        relate(object_uri, RDF.type, RDF.module_eval("#{relatorclass}"))
                      end # end if relation
                    else # literal
                      assert(value['predicate'], RDF::Literal("#{o}"))
                    end # end unless literal               
                  end # end unless.strip.empty?  
                end # end objects.each
              end # end unless objects.empty?
            end # end yamlvalue.each    
          end # end unless object.empty?

        else # we have subfields, iterate as regex matches
          
          yamlvalue['subfield'].each do | subfields | 
=begin
  here comes mapping of MARC datafields, subfield by subfield 
  subfields[0] contains subfield key
  subfields[1] contains hash of rdf mapping values from yamlfile
=end
            ####
            ## CONDITIONS: creates predicate from hash array of "match" => "replacement"
            ## mandatory: put predicate in @predicate variable for later use
            ####
            if subfields[1].has_key?('conditions')
              @predicate = ''
              ### condition by subfields                    ###
              ### if no match from given array, use default ###
              if subfields[1]['conditions'].has_key?('subfield')
                subfields[1]['conditions']['subfield'].each do | key,value |
                  m = "#{marcfield[key]}"
                  unless m.empty?
                    predicate = m.gsub(/[\W]+/, '').downcase
                    predicate.scan(/#{value['orig']}/) do |match| 
                      @predicate = value['subs'][match]
                    end
                    if @predicate.empty? then @predicate = value['default'] end
                  else
                    @predicate = value['default']
                  end
                end
              ### condition by indicators                   ###
              ### if no match from given array, use default ###
              elsif subfields[1]['conditions'].has_key?('indicator')
                if subfields[1]['conditions']['indicator']['indicator1']
                  marcfield.indicator1.scan(/#{subfields[1]['conditions']['indicator']['indicator1']['orig']}/) do |match|
                    @predicate = subfields[1]['conditions']['indicator']['indicator1']['subs'][match]
                  end
                end
                if subfields[1]['conditions']['indicator']['indicator2']
                  marcfield.indicator2.scan(/#{subfields[1]['conditions']['indicator']['indicator2']['orig']}/) do |match|
                    @predicate = subfields[1]['conditions']['indicator']['indicator2']['subs'][match]
                  end
                end
                if @predicate.empty? then @predicate = subfields[1]['conditions']['indicator']['default'] end
              end
            else
              @predicate = subfields[1]['predicate']
            end   
            ####
			## RELATIONS: make class and create relations from subfields
            ####
            if subfields[1].has_key?('relation')
=begin
  parse single subfields from yaml
=end               
               if subfields[0] 
## NEED A WAY TO USE REGEX FOR SUBFIELDS?              
                 marc_object = "#{marcfield[subfields[0]]}"
                 unless marc_object.empty?
                   objects = generate_objects(marc_object, :marcfield => marcfield, :regex_split => subfields[1]['object']['regex_split'], :urlize => subfields[1]['object']['urlize'], :regex_strip => subfields[1]['object']['regex_strip'], :regex_substitute => subfields[1]['object']['regex_substitute'], :substr_offset => subfields[1]['object']['substr_offset'], :substr_length => subfields[1]['object']['substr_length'], :combine => subfields[1]['object']['combine'], :combinestring => subfields[1]['object']['combinestring'], :downcase => subfields[1]['object']['downcase'])

                   objects.each do | o |
                     object_uri = generate_uri(o, "#{subfields[1]['object']['prefix']}")
                     # first create assertion triple
                     assert(@predicate, object_uri)

                     ## create relation class
                     relatorclass = "#{subfields[1]['relation']['class']}"
                     relate(object_uri, RDF.type, RDF.module_eval("#{relatorclass}"))
                                       
                     # do relations have subfields? parse them too ...
                     relationsubfields = subfields[1]['relation']['subfield']
                     if relationsubfields 
                       relationsubfields.each do | relsub |
                         relobject = "#{marcfield[relsub[0]]}"
                         unless relobject.empty?
                           relobjects = generate_objects(relobject, :marcfield => marcfield, :regex_split => relsub[1]['object']['regex_split'], :urlize => relsub[1]['object']['urlize'], :regex_strip => relsub[1]['object']['regex_strip'], :regex_substitute => relsub[1]['object']['regex_substitute'], :substr_offset => relsub[1]['object']['substr_offset'], :substr_length => relsub[1]['object']['substr_length'], :combine => relsub[1]['object']['combine'], :combinestring => relsub[1]['object']['combinestring'], :downcase => relsub[1]['object']['downcase'])
                           relobjects.each do | ro |
                             if relsub[1]['object']['datatype'] == "uri"
                               relobject_uri = generate_uri(ro, "#{relsub[1]['object']['prefix']}")

                               relate(object_uri, RDF.module_eval("#{relsub[1]['predicate']}"), RDF::URI(relobject_uri))
                             else
                               relate(object_uri, RDF.module_eval("#{relsub[1]['predicate']}"), RDF::Literal("#{ro}", :language => relsub[1]['object']['lang']))
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

              if subfields[0]
                marc_object = "#{marcfield[subfields[0]]}"
                unless marc_object.empty?
                  objects = generate_objects(marc_object, :marcfield => marcfield, :regex_split => subfields[1]['object']['regex_split'], :urlize => subfields[1]['object']['urlize'], :regex_strip => subfields[1]['object']['regex_strip'], :regex_substitute => subfields[1]['object']['regex_substitute'], :substr_offset => subfields[1]['object']['substr_offset'], :substr_length => subfields[1]['object']['substr_length'], :combine => subfields[1]['object']['combine'], :combinestring => subfields[1]['object']['combinestring'], :downcase => subfields[1]['object']['downcase'])
                  objects.each do | o |  
                    if subfields[1]['object']['datatype'] == "uri"
                      object_uri = generate_uri(o, "#{subfields[1]['object']['prefix']}")
                      assert(@predicate, RDF::URI(object_uri))
                    elsif subfields[1]['object']['datatype'] == "integer"
                      assert(@predicate, RDF::Literal("#{o}", :datatype => RDF::XSD.integer))
                    elsif subfields[1]['object']['datatype'] == "float"
                      assert(@predicate, RDF::Literal("#{o}", :datatype => RDF::XSD.float))
                    else # literal
                      assert(@predicate, RDF::Literal("#{o}", :language => subfields[1]['object']['lang']))
                    end # end if subfields
                  end # end objects.each do | o |
                end # end unless object.empty?           
              end
            end
          end
        end # end unless yamlvalue['subfield']
      end # end marcfields.each
    end # end match.each
  end # end record.tags.each
  end
end
