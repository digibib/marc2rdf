# coding: utf-8

$stdout.sync = true # gives foreman full stdout
require "rubygems"
require "bundler/setup"
require "sinatra/base"
require "sinatra/reloader"
require "slim"
require "json"

# RDFmodeler loads all other classes in marc2rdf
require_relative './lib/rdfmodeler.rb'

class APP < Sinatra::Base
  # Global constants
  
  configure do
  # Sinatra configs
    set :app_file, __FILE__
    set :port, 3000
    set :server, 'thin'
    set :username,'bob'
    set :token,'schabogaijk13@[]5fukkksiur!&&%&%'
    set :password,'secret'
    enable :logging, :dump_errors, :raise_errors
  end  
  
  configure :development do
    register Sinatra::Reloader
    log = File.new("logs/development.log", "a+") 
    STDOUT.reopen(log)
    STDERR.reopen(log)
    STDOUT.sync = true
    STDERR.sync = true
  end
  
  # use internal session hash, not cookies
  session = {}

  # Very simple authentication
  helpers do
    def admin? ; request.cookies[settings.username] == settings.token ; end
    def protected! ; halt [ 401, 'Not Authorized' ] unless admin? ; end
  end
  
  # Routing
  get '/' do
    # Front page
    if admin?
      slim :index, :locals => {:library => session[:library]}
    else
      slim :about, :locals => {:library => session[:library]}
    end
  end
  
  get '/libraries' do
    # Library selection
    pass if params[:id]
    :json
    slim :libraries, :locals => {:library => session[:library], :libraries => Library.new.all}
  end

  get '/libraries/:id' do
    # Library settings
    :json
    session[:library] = Library.new.find_by_id(params[:id])
    slim :libraries, :locals => {:library => session[:library], :libraries => Library.new.all}
  end
      
  get '/mapping' do
    # Primary mapping
    :json
    slim :mapping, :locals => {:library => session[:library]}
  end

=begin
### moved to API ###  
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
=end

  get '/converter' do
    # Main conversion tool
    slim :converter, :locals => {:library => session[:library]}
  end
  
  get '/harvester' do
    # Harvesting sources
    slim :harvester, :locals => {:library => session[:library]}
  end
  
  get '/settings' do
    # General settings
    session[:settings] = YAML::load( File.open( File.join(File.dirname(__FILE__), './config/', 'settings.yml')))
    slim :settings, :locals => {:library => session[:library], :settings => session[:settings]}
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
    slim :repository, :locals => {:library => session[:library], :repo => session[:repository]}
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
    slim :about, :locals => {:library => session[:library]}
  end
  
  get '/login' do
    # Login page
    slim :login
  end
  
  post '/login' do
    if params['username']==settings.username&&params['password']==settings.password
        response.set_cookie(settings.username,settings.token) 
        redirect '/'
      else
        "Username or Password incorrect"
      end
  end
  
  get '/logout' do
    response.set_cookie(settings.username, false) 
    session = {}
    redirect '/'
  end

  # start the server if ruby file executed directly
  run! if app_file == $0
end
