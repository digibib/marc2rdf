#encoding: utf-8
# Struct for Modelling MARC from RDF

require 'rdf/ntriples'

MARCModeler = Struct.new(:library, :uri, :manifestation, :marc, :marcxml)
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
    query = QUERY.select.where([self.uri, :p, :o]).from(RDF::URI(self.library.config['resource']['default_graph']))
    response = REPO.select(query)
    response.empty? ?
      self.manifestation = nil :
      self.manifestation = response
  end

  # create marc record from rdf
  def convert
    return nil unless self.manifestation # don't convert empty responses
    record = rdf2map
    marc = MARC::Record.new()
    marc.append(MARC::ControlField.new('001', record[RDF::DC.identifier][0].to_s))
    marc.append(MARC::DataField.new('100', '0',  ' ', ['a', record[RDF::DC.title][0]]))
    self.marc = marc
  end

  protected

  # this method takes rdf and generates a map from manifestation 
  # in the form {:property => ["value1", "value2"]}
  def rdf2map
    map = {}
    self.manifestation.each do |solution|
      ( map[solution[:p]] ||= []) << solution[:o].to_s
    end
    map
  end
end
