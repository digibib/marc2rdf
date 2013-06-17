#encoding: utf-8
require 'rubygems'
ENV["RACK_ENV"] ||= "development"

# require from Gemfile
require 'bundler'
Bundler.setup
Bundler.require(:default, ENV["RACK_ENV"].to_sym)

# require internal Ruby libs
require 'json'
require 'drb'

# fix broken UTF-8 during PUT requests for Ruby < 1.9.3-p392
Encoding.default_external = Encoding::UTF_8

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
SECRET_SESSION_KEY = SETTINGS["secret_session_key"]

# dynamic ruby object socket
# allows isolated processes to interact
# not needed in test environment
DRBSERVER = 'druby://localhost:9009' unless ENV['RACK_ENV'] == 'test'

# set best available XML parser for MARC
#MARC::XMLReader.best_available!

# load all library files
Dir[File.dirname(__FILE__) + '/../lib/*.rb'].each do |file|
  require file
end
