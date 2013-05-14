#encoding: utf-8
# Struct for Harvest class 

Harvest = Struct.new(:id, :name, :description, :protocol, :url, :namespaces, :predicates, :params, :limits)

class Harvest

  # a Harvest is a harvest job to be run, either at intervals or at specified time
  # Harvesting against external sources uses isbn from manifestation
  # Harvest should be managed by Scheduler via API calls
  
  def all
    harvests = []
    file     = File.join(File.dirname(__FILE__), '../db/', 'harvest.json')
    template = File.join(File.dirname(__FILE__), '../config/templates/', 'harvest.json')
    # first create harvest.json file from template if it doesn't exist already
    unless File.exist?(file)
      open(file, 'w') {|f| f.write(JSON.pretty_generate(JSON.parse(IO.read(template))))}
    end
    File.copy(template, file) unless File.exist?(file)
    data = JSON.parse(IO.read(file))
    data.each {|harvest| harvests << harvest.to_struct("Harvest") }
    harvests
  end
  
  def find(params)
    return nil unless params[:id]
    self.all.detect {|harvest| harvest.id == params[:id] }
  end
  
  
  # new harvest, repeated or frequent
  def create(params={})
    # populate Harvest Struct    
    self.members.each {|name| self[name] = params[name] unless params[name].nil? } 
    self.id         = SecureRandom.uuid
    self
  end
  
  def update(params)
    return nil unless self.id
    params.delete(:id)
    self.members.each {|name| self[name] = params[name] unless params[name].nil? }
    save
  end
  
  def save
    return nil unless self.id
    harvests = self.all
    match = self.find(:id => self.id)
    if match
      # overwrite harvest if match
      harvests.map! { |harvest| harvest.id == self.id ? self : harvest}
    else
      # new harvest if no match
      harvests << self
    end 
    open(File.join(File.dirname(__FILE__), '../db/', 'harvest.json'), 'w') {|f| f.write(JSON.pretty_generate(JSON.parse(harvest.to_json))) } 
    self
  end
  
  def delete
    return nil unless self.id
    harvests = self.all
    harvests.delete_if {|lib| lib.id == self.id }
    open(File.join(File.dirname(__FILE__), '../db/', 'harvest.json'), 'w') {|f| f.write(JSON.pretty_generate(JSON.parse(harvest.to_json))) } 
    harvests
  end
  
  def reload
    self.find(:id => self.id)
  end  
  
end
