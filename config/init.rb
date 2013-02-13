#encoding: utf-8
require 'rubygems'
ENV["RACK_ENV"] ||= "development"

require 'bundler'
Bundler.setup
Bundler.require(:default, ENV["RACK_ENV"].to_sym)

require 'marc'
require 'yaml'
require 'rdf'
require 'rdf/rdfxml'
require 'rdf/n3'
require 'rdf/ntriples'
require 'rdf/virtuoso'
require 'json'

# Defaults
# Can be deleted when App settings is finished
#$config_file = File.join(File.dirname(__FILE__), '..', '/config/config.yml') unless $config_file
# read configuration file into constants
$config_file  = File.join(File.dirname(__FILE__), '../config/', 'settings.json')
SETTINGS      = JSON.parse(IO.read($config_file))
REPO          = RDF::Virtuoso::Repository.new(
              SETTINGS["repository"]["sparql_endpoint"],
              :update_uri => SETTINGS["repository"]["sparul_endpoint"],
              :username => SETTINGS["repository"]["username"],
              :password => SETTINGS["repository"]["password"],
              :auth_method => SETTINGS["repository"]["auth_method"])

#REVIEWGRAPH        = RDF::URI(repository["reviewgraph"])
#BOOKGRAPH          = RDF::URI(repository["bookgraph"])
#APIGRAPH           = RDF::URI(repository["apigraph"])
QUERY              = RDF::Virtuoso::Query
#BASE_URI           = repository["base_uri"]
SECRET_SESSION_KEY = "alongandveryshortstring"

# load all library files
Dir[File.dirname(__FILE__) + '/../lib/*.rb'].each do |file|
  require file
end
