#encoding: utf-8
# Struct for Libraries saved in json
Library = Struct.new(:id, :name, :config, :mapping, :oai, :harvesting)
class Library
  def all
    libraries = []
    file     = File.join(File.dirname(__FILE__), '../db/', 'libraries.json')
    template = File.join(File.dirname(__FILE__), '../db/templates/', 'libraries.json')
    # first create library file from template if it doesn't exist already
    unless File.exist?(file)
      open(file, 'w') {|f| f.write(JSON.pretty_generate(JSON.parse(IO.read(template))))}
    end
    File.copy(template, file) unless File.exist?(file)
    data = JSON.parse(IO.read(file))
    data.each {|lib| libraries << lib.to_struct("Library") }
    libraries
  end
  
  def find_by_id(id)
    library = self.all.detect {|lib| lib['id'] == id.to_i }
  end

  def create(params={})
    ids = []
    self.all.each {|lib| ids << lib['id']}
    library = Library.new(
      # find highest id and increase by one
      ids.empty? ? 1 : ids.max + 1,
      params[:name],
      params[:config]     ||= {:resource => {} },
      params[:mapping]    ||= {},
      params[:oai]        ||= {:preserve_on_update => [] },
      params[:harvesting] ||= {}
      )
  end
  
  def update(params={})
    libraries = self.all
    library   = self.find_by_id(params[:id])
    # remove unwanted params
    unwanted_params = ['uri', 'api_key', 'route_info', 'method', 'path']
    unwanted_params.each {|d| params.delete(d)}
    # update review with new params
    params.each{|k,v| library[k] = v}
    library
  end
  
  def save(library)
    libraries = self.all
    # update if matching id, else append
    match = self.find_by_id(library.id)
    if match
      libraries.map! { |lib| lib.id == library.id ? library : lib}
    else
      libraries << library
    end
    open(File.join(File.dirname(__FILE__), '../db/', 'libraries.json'), 'w') {|f| f.write(JSON.pretty_generate(JSON.parse(libraries.to_json))) } 
    libraries
  end
  
  def delete(id)
    # reads in all libraries and deletes library 'id' from json store
    libraries = self.all
    libraries.delete_if {|lib| lib.id == id }
    open(File.join(File.dirname(__FILE__), '../db/', 'libraries.json'), 'w') {|f| f.write(JSON.pretty_generate(JSON.parse(libraries.to_json))) } 
    libraries
  end
  
  def reload
    self.find_by_id(self.id)
  end
end
