#encoding: utf-8
# Struct for Libraries saved in json
Library = Struct.new(:id, :name, :config, :mapping, :oai, :rules, :harvesters)
class Library
  
  ## Class methods
  def self.all
    libraries = []
    file     = File.join(File.dirname(__FILE__), '../db/', 'libraries.json')
    template = File.join(File.dirname(__FILE__), '../config/templates/', 'libraries.json')
    # first create library file from template if it doesn't exist already
    unless File.exist?(file)
      open(file, 'w') {|f| f.write(JSON.pretty_generate(JSON.parse(IO.read(template))))}
    end
    File.copy(template, file) unless File.exist?(file)
    data = JSON.parse(IO.read(file))
    data.each {|lib| libraries << lib.to_struct("Library") }
    libraries
  end
  
  def self.find(params)
    return nil unless params[:id] || params[:name]
    if params[:id]
      Library.all.detect {|lib| lib['id'] == params[:id] }
    elsif params[:name]
      Library.all.detect {|lib| lib['name'] == params[:name] } 
    end
  end
  
  ## Instance methods
  def create(params={})
    ids = []
    Library.all.each {|lib| ids << lib['id']}
    # populate Library Struct    
    self.members.each {|name| self[name] = params[name] unless params[name].nil? }  
    # find highest id and increase by one
    ids.empty? ? self.id = 1 : self.id = ids.max + 1
    self
  end
  
  def update(params={})
    return nil unless self.id
    self.members.each {|name| self[name] = params[name] unless params[name].nil? }
    save
    self
  end
  
  def save
    return nil unless self.id
    libraries = Library.all
    match = Library.find(:id => self.id)
    if match
      # overwrite library if match
      libraries.map! { |lib| lib.id == self.id ? self : lib}
    else
      # new library if no match
      libraries << self
    end 
    open(File.join(File.dirname(__FILE__), '../db/', 'libraries.json'), 'w') {|f| f.write(JSON.pretty_generate(JSON.parse(libraries.to_json))) } 
    self
  end
  
  def delete
    return nil unless self.id
    libraries = Library.all
    libraries.delete_if {|lib| lib.id == self.id }
    open(File.join(File.dirname(__FILE__), '../db/', 'libraries.json'), 'w') {|f| f.write(JSON.pretty_generate(JSON.parse(libraries.to_json))) } 
    libraries
  end
  
  def reload
    Library.find(:id => self.id)
  end
end
