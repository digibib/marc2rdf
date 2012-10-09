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

class Mapping
  attr_accessor :file, :mapping

  def initialize(filename)
    # local variables
    mapping_skeleton = YAML::load( File.open( File.join(File.dirname(__FILE__), '../db/templates/', 'mapping_skeleton.yml') ) )
    mapping          = File.join(File.dirname(__FILE__), '../db/mapping/', filename)
    # serialize skeleton into mapping file if not found
    unless File.exist?(mapping)
      open(mapping, 'w') {|f| YAML.dump(mapping_skeleton, f)}
    end
    @file       = YAML::Store.new(mapping, :Indent => 2)
    @mapping    = YAML::load(File.open(mapping))
  end
  
  def save
    @file.transaction do
      @file['tags'] = @mapping['tags'] if @mapping['tags']
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
