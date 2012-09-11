require 'rubygems'
require 'bundler/setup'
require 'sequel'
require 'yaml'

CONFIG      = YAML::load_file('config/config.yml')
MAPPINGFILE = YAML::load_file(CONFIG['mapping']['file'])

DB = Sequel.sqlite

puts MAPPINGFILE
