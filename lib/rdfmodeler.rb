# Initialize additional vocabularies we will be drawing from
# Existing vocabularies are listed on http://rdf.rubyforge.org/
# NB! protected methods must be overridden! (with e.g. property :name)
module RDF
  class BIBO < RDF::Vocabulary("http://purl.org/ontology/bibo/");end
  class RDFS < RDF::Vocabulary("http://www.w3.org/2000/01/rdf-schema#");end
  class XFOAF < RDF::Vocabulary("http://www.foafrealm.org/xfoaf/0.1/")
    property :name
  end
  class LEXVO < RDF::Vocabulary("http://lexvo.org/ontology#")
    property :name
  end
  class DEICHMAN < RDF::Vocabulary("http://data.deichman.no/");end
  class DBO < RDF::Vocabulary("http://dbpedia.org/ontology/");end
  class FABIO < RDF::Vocabulary("http://purl.org/spar/fabio/");end
  class FRBR < RDF::Vocabulary("http://purl.org/vocab/frbr/core#");end  
  class RDA < RDF::Vocabulary("http://rdvocab.info/Elements/");end  
  class GEONAMES < RDF::Vocabulary("http://www.geonames.org/ontology#")
    property :name
  end  
  class MO < RDF::Vocabulary("http://purl.org/ontology/mo/");end
  class YAGO < RDF::Vocabulary("http://dbpedia.org/class/yago/");end 
  class CTAG < RDF::Vocabulary("http://commontag.org/ns#");end 
end

class RDFModeler
  attr_reader :record, :statements, :uri
  def initialize(record)
    @record = record
    construct_uri
    $statements = []
  end
    
  def construct_uri
    @uri = RDF::URI.intern(CONFIG['resource']['base'] + CONFIG['resource']['resource_path'] + CONFIG['resource']['resource_prefix'])
    id = @record[CONFIG['resource']['resource_identifier_field']]
    @uri += id.value.to_i
  end

  def set_type(t)
    $statements << RDF::Statement.new(@uri, RDF.type, RDF.module_eval("#{t}"))
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

  regex_subs = options[:regex_substitute]
# remove nil options
  options.delete_if {|k,v| v.nil?}
  #p options

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
        options[:combine].each { | c | obj2 << options[:marcfield][c] }
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

  return generated_objects
  end
  
  def assert(p, o)
    $statements << RDF::Statement.new(@uri, RDF.module_eval("#{p}"), o)
  end
  
  def relate(s, p, o)
    $statements << RDF::Statement.new(RDF::URI(s), p, o)
  end

  def write_record
      $statements.each do | statement |
      #p statement
        @@writer << statement
      end
  end
  
  def marc2rdf_convert(record)
  # start graph handle, one graph per record, else graph will grow too large to parse
  record.tags.each do | marctag | 
    # put all marc tag fields into array object 'marcfields' for later use
    marcfields = record.find_all { |field| field.tag == marctag }
    # start matching MARC tags against yamltags, put results in match array
    match = @@yamltags.select { |k,v| marctag  =~ /#{k}/ }
    match.each do |yamlkey,yamlvalue|
    # iterate each marc tag array object to catch multiple marc fields 
      marcfields.each do | marcfield | 

        # controlfields 001-009 don't have subfields
        unless yamlvalue.has_key?('subfield')
          # do controlfields here ... to be done
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
