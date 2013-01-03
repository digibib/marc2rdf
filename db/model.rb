require 'rdf/virtuoso'
require 'sinatra'
require 'yaml/store'

# yaml/store main method:
# initialize( file_name, yaml_opts = {} )
Library = Struct.new(:id, :name, :config, :mapping, :oai, :harvesting)

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


class Library
  def all
    libraries = JSON.parse(IO.read(File.join(File.dirname(__FILE__), 'libraries.json')))
  end
  
  def find_by_id(id)
  end

  def create(args={})
    ids = []
    self.all['libraries'].each {|ll| ids << ll['id']}
    library = Library.new(
      ids.max + 1,
      args[:name],
      args[:config],
      args[:mapping],
      args[:oai],
      args[:harvesting]
      )
  end
  
  def save
    open('libraries.json', 'w') {|f| f.write(JSON.pretty_generate(JSON.parse(Library.new.all))) } 
  end
end

class Map
  attr_accessor :file, :mapping

  def initialize(filename = 'mapping.json')
    # local variables
    mapping_skeleton = File.read( File.join(File.dirname(__FILE__), 'templates', 'mapping_skeleton.json'))
    mapping          = File.join(File.dirname(__FILE__), '../db/mapping/', filename)
    # serialize skeleton into mapping file if not found
    unless File.exist?(mapping)
      open(mapping, 'w') {|f| f.write(JSON.pretty_generate(JSON.parse(mapping_skeleton))) } 
    end
    @file       = mapping
    @mapping    = JSON.parse(IO.read(@file))
  end
  
  def find_by_library(id)
    mappingdir = id + '/mapping/'
    if File.directory? mappingdir
      @file    = File.join(File.dirname(__FILE__), mappingdir, 'mapping.json')
      @mapping = JSON.parse(IO.read(@file))
    else
      return nil
    end
  end
  
  def reload
    if @mapping
      @mapping = JSON.parse(IO.read(@file))
    end  
  end
  
  def save
    if @mapping
      open(@file, 'w') {|f| f.write(JSON.pretty_generate(JSON.parse(@mapping))) } 
    end
  end
end

class Harvest
  attr_reader   :harvesting_skeleton
  attr_accessor :filename, :sources, :options

  def initialize(filename)
    @harvesting_skeleton = YAML::load( File.open( File.join(File.dirname(__FILE__), '../db/templates/', 'harvesting_skeleton.yml') ) )
    @harvest = YAML::Store.new( File.join(File.dirname(__FILE__), '../db/harvesting/', filename), :Indent => 2 )
  end
  
  def save
    @harvest.transaction do
      @harvest['sources'] = @sources
      @harvest['options'] = @options
    end
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
    Struct.new(name, *keys).new(*values)
  end
end
