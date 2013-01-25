require 'rdf/virtuoso'
require 'sinatra'
require 'yaml/store'

# yaml/store main method:
# initialize( file_name, yaml_opts = {} )

class Repo
  attr_accessor :file, :repository, :endpoint

  def initialize(filename)
    # local variables
    repository_skeleton = YAML::load( File.open( File.join(File.dirname(__FILE__), '../db/templates/', 'repository_skeleton.yml') ) )
    repository          = File.join(File.dirname(__FILE__), '../db/repository/', filename)
    # serialize skeleton into repository file if not found
    unless File.exist?(repository)
      open(repository, 'w') {|f| YAML.dump(repository_skeleton, f)}
    end
    
    @file       = YAML::Store.new(repository, :Indent => 2)
    @repository = YAML::load(File.open(repository))
    rdfstore  = @repository['rdfstore']
    @endpoint = RDF::Virtuoso::Repository.new(
                      rdfstore['sparql_endpoint'] || ENV['SPARQL_ENDPOINT'], 
      :update_uri  => rdfstore['sparul_endpoint'] || ENV['SPARUL_ENDPOINT'], 
      :username    => rdfstore['username']        || ENV['USERNAME'],
      :password    => rdfstore['password']        || ENV['PASSWORD'],
      :auth_method => rdfstore['auth_method']     || ENV['AUTH_METHOD']
    )
  end
  
  def save
    @file.transaction do
      @file['resource'] = @repository['resource'] if @repository['resource']
      @file['rdfstore'] = @repository['rdfstore'] if @repository['rdfstore']
      @file['oai']      = @repository['oai']      if @repository['oai']
    end
  end
end

# Struct for Libraries saved in json
Library = Struct.new(:id, :name, :config, :mapping, :oai, :harvesting)
class Library
  def all
    libraries = []
    file     = File.join(File.dirname(__FILE__), 'libraries.json')
    template = File.join(File.dirname(__FILE__), 'templates/', 'libraries.json')
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
    open(File.join(File.dirname(__FILE__), 'libraries.json'), 'w') {|f| f.write(JSON.pretty_generate(JSON.parse(libraries.to_json))) } 
    libraries
  end
  
  def delete(id)
    libraries = self.all
    libraries.delete_if {|lib| lib.id == id }
    open(File.join(File.dirname(__FILE__), 'libraries.json'), 'w') {|f| f.write(JSON.pretty_generate(JSON.parse(libraries.to_json))) } 
    libraries
  end
end

# patched Struct and Hash classes to allow easy conversion to/from JSON and Hash
class Struct
  def to_map
    map = Hash.new
    self.members.each { |m| map[m] = self[m] }
    # strip out empty struct values
    map.reject! {|k,v| v.strip.empty? if v.is_a?(String) && v.respond_to?('empty?')}
    map
  end
  def to_json(*a)
    to_map.to_json(*a)
  end
end

class Hash
  def to_struct(name)
    cls = Struct.const_get(name) rescue Struct.new(name, *keys)
    cls.new *values
  end
end
