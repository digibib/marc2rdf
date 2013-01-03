#encoding: UTF-8
$stdout.sync = true # gives foreman full stdout

if RUBY_VERSION <= "1.8.7" then $KCODE = 'u' end #needed for string conversion in ruby 1.8.7
require "rubygems"
require "bundler/setup"
require "sinatra"
require "sinatra/reloader" if development?
require "slim"
require "json"

# RDFmodeler loads all other classes in marc2rdf
require_relative './lib/rdfmodeler.rb'

class APP < Sinatra::Base
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

  get '/libraries' do
    # Library selection
    :json
    slim :libraries, :locals => {:library => session[:library]}
  end
    
  get '/mapping' do
    # Primary mapping
    :json
    slim :mapping, :locals => {:library => session[:library]}
  end
  
  get '/mapping/json' do
    :json
    session[:mapping].reload
    #file = File.read( File.join(File.dirname(__FILE__), './db/mapping/', 'mapping.json'))
    #session[:mapping] = JSON.parse(file).to_json
  end
  
  put '/mapping' do
    # Save modified mapping
    
    session[:mapping].mapping = JSON.parse(request.body.read).to_json
    puts session[:mapping]
    session[:mapping].save
    #File.open( File.join(File.dirname(__FILE__), './db/mapping/', 'test2.json'), 'w') do |f| 
    #  f.write(JSON.pretty_generate(session[:mapping])) 
    #end
    #{ :msg => "saved!" }
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
    # General settings
    session[:settings] = YAML::load( File.open( File.join(File.dirname(__FILE__), './config/', 'settings.yml')))
    slim :settings, :locals => {:settings => session[:settings]}
  end
  
  put '/settings' do
    # Save general settings
    settings = YAML::Store.new( File.join(File.dirname(__FILE__), 'config/settings.yml'), :Indent => 2 )
    settings.transaction do
      settings['files'] = params['files'] if params['files']
    end
  end
  
  get '/repository' do
    # Misc. repository settings
    session[:repository] = Repo.new('repository.yml')
    slim :repository, :locals => {:repo => session[:repository]}
  end
  
  put '/repository' do
    # Save/update repository settings
    session[:repository].repository['rdfstore'] = params['rdfstore'] if params['rdfstore']
    session[:repository].repository['resource'] = params['resource'] if params['resource']
    session[:repository].repository['oai']      = params['oai']      if params['oai']
    session[:repository].save
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
end
