#encoding: utf-8
# Struct for Modelling MARC from RDF

require 'rdf/ntriples'

MARCModeler = Struct.new(:library, :uri, :manifestation, :marcxml)
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
    self.manifestation = response
  end

  ## Class Methods

  # method to output marc xml
  def self.write_marcxml(record)
  end
end
