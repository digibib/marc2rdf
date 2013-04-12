#encoding: utf-8
# Struct for Mapping class 

Mapping = Struct.new(:id, :name, :description, :mapping)
class Mapping

  # a Mapping is a JSON mapping from MARC 2 RDF
  
  def all
    mappings = []
    file     = File.join(File.dirname(__FILE__), '../db/', 'mappings.json')
    template = File.join(File.dirname(__FILE__), '../config/templates/', 'mappings.json')
    # first create library file from template if it doesn't exist already
    unless File.exist?(file)
      open(file, 'w') {|f| f.write(JSON.pretty_generate(JSON.parse(IO.read(template))))}
    end
    File.copy(template, file) unless File.exist?(file)
    data = JSON.parse(IO.read(file))
    data.each {|mapping| mappings << mapping.to_struct("Mapping") }
    mappings
  end
  
  def find(params)
    return nil unless params[:id]
    self.all.detect {|mapping| mapping.id == params[:id] }
  end
  
  def find_by_tag()
  end
  
  # new mapping
  def create(params={})
    # populate Mapping Struct    
    self.members.each {|name| self[name] = params[name] unless params[name].nil? } 
    self.id         = SecureRandom.uuid
    self
  end
  
  def update(params)
    return nil unless self.id
    return nil unless validate_mapping
    params.delete(:id)
    self.members.each {|name| self[name] = params[name] unless params[name].nil? }
    save
  end
  
  def save
    return nil unless self.mapping
    return nil unless validate_mapping
    mappings = self.all
    match = self.find(:id => self.id)
    if match
      # overwrite rule if match
      mappings.map! { |mapping| mapping.id == self.id ? self : mapping}
    else
      # new rule if no match
      mappings << self
    end 
    open(File.join(File.dirname(__FILE__), '../db/', 'mappings.json'), 'w') {|f| f.write(JSON.pretty_generate(JSON.parse(mappings.to_json))) } 
    self
  end
  
  def delete
    return nil unless self.id
    mappings = self.all
    mappings.delete_if {|lib| lib.id == self.id }
    open(File.join(File.dirname(__FILE__), '../db/', 'mappings.json'), 'w') {|f| f.write(JSON.pretty_generate(JSON.parse(mappings.to_json))) } 
    mappings
  end
  
  def reload
    self.find(:id => self.id)
  end  
  
  def validate_mapping
    begin
      JSON.parse(self.mapping.to_json)
      return true
    rescue JSON::ParserError
      return false
    end
  end
end
