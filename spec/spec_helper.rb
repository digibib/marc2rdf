require 'rubygems'
require 'bundler/setup'
require 'rdf/spec'
require 'rdf'
require 'oai'
require 'rdf/virtuoso'
require 'sinatra/base'
require 'webmock/rspec'

ENV['RACK_ENV'] = 'test'

if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start do
    add_filter '/spec'
  end
end

# code init
require File.join(File.dirname(__FILE__), '..', 'config', 'init.rb')
require File.join(File.dirname(__FILE__), '..', 'app.rb')
require File.join(File.dirname(__FILE__), '..', 'api.rb')
require File.join(File.dirname(__FILE__), '..', 'scheduler.rb')


RSpec.configure do |config|
  config.include Rack::Test::Methods
  config.mock_with :rspec
  config.expect_with :rspec
end
