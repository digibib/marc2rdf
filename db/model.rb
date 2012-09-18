require 'sinatra'
require 'yaml/store'
# yaml/store main method:
# initialize( file_name, yaml_opts = {} )

class Repo
  attr_reader   :repository_skeleton
  attr_accessor :filename, :resource, :rdfstore, :oai

  def initialize(filename)
    @repository_skeleton = YAML::load( File.open( File.join(File.dirname(__FILE__), '../db/templates/', 'repository_skeleton.yml') ) )
    @repo = YAML::Store.new( File.join(File.dirname(__FILE__), '../db/repository/', filename), :Indent => 2 )
  end
  
  def save
    @repo.transaction do
      @repo['resource'] = @resource
      @repo['rdfstore'] = @rdfstore
      @repo['oai']      = @oai
    end
  end
end

class Harvest
  attr_reader   :harvesting_skeleton
  attr_accessor :filename, :sources, :options

  def initialize(filename)
    @harvesting_skeleton = YAML::load( File.open( File.join(File.dirname(__FILE__), '../db/templates/', 'harvesting_skeleton.yml') ) )
    @harvest = YAML::Store.new( File.join(File.dirname(__FILE__), '../db/repository/', filename), :Indent => 2 )
  end
  
  def save
    @repo.transaction do
      @harvest['sources'] = @sources
      @harvest['options'] = @options
    end
  end
end

class Mapping
  attr_reader   :mapping_skeleton
  attr_accessor :filename, :tags

  def initialize(filename)
    @mapping_skeleton    = YAML::load( File.open( File.join(File.dirname(__FILE__), '../db/templates/', 'mapping_skeleton.yml') ) )
    @map = YAML::Store.new( File.join(File.dirname(__FILE__), '../db/repository/', filename), :Indent => 2 )
  end
  
  def save
    @map.transaction do
      @map['tags'] = @tags
    end
  end
end
