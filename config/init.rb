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

# Defaults
# Can be deleted when App settings is finished
$config_file = File.join(File.dirname(__FILE__), '..', '/config/config.yml') unless $config_file
# read configuration file into constants
repository  = YAML::load(File.open($config_file))
REPO        = RDF::Virtuoso::Repository.new(
              repository["sparql_endpoint"],
              :update_uri => repository["sparul_endpoint"],
              :username => repository["username"],
              :password => repository["password"],
              :auth_method => repository["auth_method"])

REVIEWGRAPH        = RDF::URI(repository["reviewgraph"])
BOOKGRAPH          = RDF::URI(repository["bookgraph"])
APIGRAPH           = RDF::URI(repository["apigraph"])
QUERY              = RDF::Virtuoso::Query
BASE_URI           = repository["base_uri"]
SECRET_SESSION_KEY = repository["secret_session_key"]

# load all library files
Dir[File.dirname(__FILE__) + '/../lib/*.rb'].each do |file|
  require file
end
