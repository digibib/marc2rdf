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
$config_file = File.join(File.dirname(__FILE__), '..', '/config/config.yml') unless $config_file

# load all library files
Dir[File.dirname(__FILE__) + '/../lib/*.rb'].each do |file|
  require file
end
