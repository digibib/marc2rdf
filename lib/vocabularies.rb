#encoding: utf-8

Vocabulary = Struct.new(:prefix, :uri)
class Vocabulary
  # Simple Class for RDF Vocabularies used in app 
  
  ## Class methods
  
  def self.all
    vocabularies = []
    file     = File.join(File.dirname(__FILE__), '../db/', 'vocabularies.json')
    template = File.join(File.dirname(__FILE__), '../config/templates/', 'vocabularies.json')
    # first create vocabularies.json file from template if it doesn't exist already
    unless File.exist?(file)
      open(file, 'w') {|f| f.write(JSON.pretty_generate(JSON.parse(IO.read(template))))}
    end
    File.copy(template, file) unless File.exist?(file)
    data = JSON.parse(IO.read(file))
    data.each {|vocabulary| vocabularies << vocabulary.to_struct("Vocabulary") }
    vocabularies
  end
  
  def self.find(params)
    return nil unless params[:prefix]
    Vocabulary.all.detect {|vocab| vocab.prefix == params[:prefix] }
  end

  ## Instance methods  
  
  # add new vocabulary
  def create(params={})
    self.members.each {|name| self[name] = params[name] unless params[name].nil? } 
    self
  end
  
  def update(params={})
    self.members.each {|name| self[name] = params[name] unless params[name].nil? }
    save
    self
  end
  
  def save
    return nil unless self.prefix
    protected = [:VERSION, :VOCABS, :RDFXML, :XML, :N3, :IRI, :URI]
    # ignore predefined? presently no
    ignore = [:DC, :FOAF, :DC11, :RDFS, :WOT, :XSD, :HTTP, :MA, :DOAP, :RSS, :CC, :GEO, :EXIF, 
        :CERT, :SIOC, :SKOS, :OWL, :XHTML, :RSA, :LOG, :REI]
    return nil if protected.any? {|p| self.prefix.upcase.to_sym == p }
    vocabularies = Vocabulary.all
    match = Vocabulary.find(:prefix => self.prefix)
    if match
      # overwrite vocab if match
      vocabularies.map! { |vocab| vocab.prefix == self.prefix ? self : vocab}
    else
      # new vocab if no match
      vocabularies << self
    end 
    open(File.join(File.dirname(__FILE__), '..', 'db', 'vocabularies.json'), 'w') {|f| f.write(JSON.pretty_generate(JSON.parse(vocabularies.to_json))) } 
    self.set
    self
  end
  
  def delete
    vocabularies = Vocabulary.all
    vocabularies.delete_if {|vocab| vocab.prefix == self.prefix }
    open(File.join(File.dirname(__FILE__), '..', 'db', 'vocabularies.json'), 'w') {|f| f.write(JSON.pretty_generate(JSON.parse(vocabularies.to_json))) } 
    self.unset
  end
  
  # defines RDF Vocabulary
  def set
    RDF.send(:const_set, self.prefix.upcase.to_sym, RDF::Vocabulary.new("#{self.uri}"))
  end  

  # undefines RDF Vocabulary
  def unset
    const = self.prefix.upcase.to_sym
    RDF.send(:remove_const, const) if RDF.const_defined?(const)
  end
  
end
