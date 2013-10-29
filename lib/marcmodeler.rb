#encoding: utf-8
# Struct for Modelling MARC from RDF

require 'rdf/ntriples'

MARCModeler = Struct.new(:library, :uri, :manifestation, :marc)
class MARCModeler

  ## Constructor
  # Takes either:
  # - uri of resource and converts to MARCXML
  # - RDF::Solutions already with bindings :p and :o 
  def initialize(library)
    self.library  = library
  end
  
  def get_manifestation(uri)
    self.uri = RDF::URI(uri)
    query = QUERY.select.where(
      [self.uri, RDF::DC.identifier, :id],
      [self.uri, RDF::DC.title, :title]
    )
    query.optional([self.uri, RDF::RDA.statementOfResponsibility, :responsible])
    query.optional(
      [self.uri, RDF::DC.creator, :creatorURI],
      [:creatorURI, RDF::RADATANA.catalogueName, :creatorName],
      [:creatorURI, RDF::DC.identifier, :creatorID])
    query.optional([self.uri, RDF::DEICH.location_signature, :locationSignature])
    query.optional([self.uri, RDF::FABIO.hasSubtitle, :hasSubtitle])
    query.optional([self.uri, RDF::DEICH.ageLimit, :ageLimit])
    query.optional([self.uri, RDF::BIBO.isbn, :isbn])
    query.optional([self.uri, RDF::BIBO.issn, :issn])
    query.from(RDF::URI(self.library.config['resource']['default_graph']))
    #puts query
    
    response = REPO.select(query)
    response.empty? ?
      self.manifestation = nil :
      self.manifestation = response
  end

  # create marc record from rdf
  def convert
    return nil unless self.manifestation # don't convert empty responses
    record = rdf2map
    marc = generate_marc(record)
    self.marc = marc
  end

  def to_xml
    return nil unless self.marc # dont try to convert nil
    marc.to_xml
  end

  protected
  # this method takes RDF::Solutions and generates a map from manifestation 
  # in the form {:property => ["value1", "value2"]}
  def rdf2map
    map = {}
    self.manifestation.each do |solution|
      solution.each_binding do | name,value |
        # create hash with array and append unless already present 
        ( map[name] ||= []) << solution[name].to_s unless map[name] && map[name].include?(solution[name].to_s)
      end
    end
    map
  end

  def generate_marc(record)
    # MARC::Record must be composed serially!
    marc = MARC::Record.new()
    marc.append(MARC::ControlField.new('001', record[:id][0].to_s)) 
    marc.append(MARC::DataField.new('019', ' ',  ' ', ['s', record[:ageLimit][0]])) if record[:ageLimit]
    marc.append(MARC::DataField.new('020', ' ',  ' ', ['a', record[:isbn][0]])) if record[:isbn]
    marc.append(MARC::DataField.new('021', ' ',  ' ', ['a', record[:issn][0]])) if record[:issn]
    marc.append(MARC::DataField.new('090', ' ',  ' ', ['d', record[:locationSignature][0]])) if record[:locationSignature]
    if record[:creatorName]
      field100 = MARC::DataField.new('100', ' ',  ' ')
        field100.append( MARC::Subfield.new('3', record[:creatorID][0])) if record[:creatorID]
        field100.append( MARC::Subfield.new('a', record[:creatorName][0])) 
        marc.append(field100)
    end
    field245 = MARC::DataField.new('245', ' ',  ' ')
      field245.append( MARC::Subfield.new('a', record[:title][0])) if record[:title]
      field245.append( MARC::Subfield.new('b', record[:hasSubtitle][0])) if record[:hasSubtitle]
      field245.append( MARC::Subfield.new('c', record[:responsible][0])) if record[:responsible]
      field245.append( MARC::Subfield.new('p', record[:hasSubtitle][0])) if record[:hasSubtitle]
      marc.append(field245) 
    marc
  end
end
