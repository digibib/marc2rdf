require 'rubygems'
require 'bundler/setup'
require 'rdf/spec'
require 'rspec/mocks'
require 'rdf'
require 'oai'
require 'rdf/virtuoso'
require 'sinatra/base'
#require 'sinatra/spec'
#require 'minitest/autorun'
require 'webmock/rspec'

ENV['RACK_ENV'] = 'test'

require File.join(File.dirname(__FILE__), '../config/', 'init.rb')
require File.join(File.dirname(__FILE__), '..', 'app.rb')
require File.join(File.dirname(__FILE__), '..', 'api.rb')
require File.join(File.dirname(__FILE__), '..', 'scheduler.rb')

if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start
end

RSpec.configure do |config|
  #config.include Rack::Test::Methods
  config.mock_with :rspec
  config.expect_with :rspec
end
