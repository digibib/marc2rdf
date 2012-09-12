#encoding: UTF-8
if RUBY_VERSION <= "1.8.7" then $KCODE = 'u' end #needed for string conversion in ruby 1.8.7
require "rubygems"
require "bundler/setup"
require "sinatra"
require "sinatra/reloader" if development?
require "slim"
require "json"

# RDFmodeler loads all other classes in marc2rdf
require_relative './lib/rdfmodeler.rb'

# Global constants

# Sinatra configs
session = {}
set :server, 'thin'
set :username,'bob'
set :token,'schabogaijk13@[]5fukkksiur!&&%&%'
set :password,'secret'

# Very simple authentication
helpers do
  def admin? ; request.cookies[settings.username] == settings.token ; end
  def protected! ; halt [ 401, 'Not Authorized' ] unless admin? ; end
end

# Routing
get '/' do
  # Front page
  if admin?
    slim(:index)  
  else
    slim(:about)
  end
end

get '/mapping' do
  # Mapping tool
  slim(:mapping)  
end
get '/converter' do
  # Main conversion tool
  slim(:converter)  
end

get '/harvester' do
  # Harvesting sources
  slim(:harvester)  
end

get '/settings' do
  # Misc. settings
  slim(:settings)  
end

get '/about' do
  # Front page
  slim(:about)  
end

get '/login' do
  # Login page
  slim(:login)
end

post '/login' do
  if params['username']==settings.username&&params['password']==settings.password
      response.set_cookie(settings.username,settings.token) 
      redirect '/'
    else
      "Username or Password incorrect"
    end
end

get('/logout'){ response.set_cookie(settings.username, false) ; redirect '/' }
