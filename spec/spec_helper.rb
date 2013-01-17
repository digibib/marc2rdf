require 'rubygems'
require 'bundler/setup'
require 'rdf/spec'
require 'rspec/mocks'
require 'rdf'
require 'oai'
require 'rdf/virtuoso'
require 'sinatra/base'
require 'sinatra/spec'

#require_relative '../../rdf-virtuoso/lib/rdf/virtuoso'
require_relative '../lib/rdfmodeler.rb'
require File.join(File.dirname(__FILE__), '..', 'app.rb')
require File.join(File.dirname(__FILE__), '..', 'api.rb')

if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start
end

RSpec.configure do |config|
  config.include Rack::Test::Methods
end
