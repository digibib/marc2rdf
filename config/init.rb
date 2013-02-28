#encoding: utf-8
require 'rubygems'
ENV["RACK_ENV"] ||= "development"

require 'bundler'
Bundler.setup
Bundler.require(:default, ENV["RACK_ENV"].to_sym)

require 'json'
require 'drb'

# read configuration file into constants
CONFIG_FILE   = File.join(File.dirname(__FILE__), '../config/', 'settings.json')
SETTINGS      = JSON.parse(IO.read(CONFIG_FILE))
REPO          = RDF::Virtuoso::Repository.new(
              SETTINGS["repository"]["sparql_endpoint"],
              :update_uri => SETTINGS["repository"]["sparul_endpoint"],
              :username => SETTINGS["repository"]["username"],
              :password => SETTINGS["repository"]["password"],
              :auth_method => SETTINGS["repository"]["auth_method"])

QUERY              = RDF::Virtuoso::Query
SECRET_SESSION_KEY = "alongandveryshortstring"

# dynamic ruby object socket
# allows processes to interact
DRBSERVER     = 'druby://localhost:9009'

# load all library files
Dir[File.dirname(__FILE__) + '/../lib/*.rb'].each do |file|
  require file
end
