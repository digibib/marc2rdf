#encoding: utf-8

$stdout.sync = true # gives foreman full stdout
require_relative "./config/init.rb"
require "sinatra/base"
require "sinatra/reloader"
require "sinatra/synchrony"
require "sinatra/streaming"
require "slim"
require "json"



class APP < Sinatra::Base
  # Global constants
  
  configure do
  # Sinatra configs
    register Sinatra::Synchrony
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
    #Faraday.default_adapter = :em_synchrony
    log = File.new("logs/development.log", "a+") 
    #STDOUT.reopen(log)
    #STDERR.reopen(log)
    #STDOUT.sync = true
    #STDERR.sync = true
  end
  
  # use internal session hash, not cookies
  session = {}

  # Very simple authentication
  helpers do
    Sinatra::Streaming
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
    :json
    # reload session if updated, can be optimzed!
    session[:library] = session[:library].reload if session[:library] 
    slim :libraries, :locals => {:library => session[:library], :libraries => Library.new.all}
  end

  get '/libraries/:id' do
    # Library settings
    :json
    puts params
    session[:library] = Library.new.find(:id => params[:id].to_i)
    slim :libraries, :locals => {:library => session[:library], :libraries => Library.new.all}
  end
      
  get '/mapping' do
    # Primary mapping
    :json
    slim :mapping, :locals => {:library => session[:library]}
  end

  get '/oai' do
    # oai settings
    :json
    # reload session if updated, can be optimzed!
    session[:library] = session[:library].reload if session[:library] 
    slim :oai, :locals => {:library => session[:library]}
  end
  
  get '/convert' do
    # Main conversion tool
    slim :convert, :locals => {:library => session[:library]}
  end
  
  get '/harvest' do
    # Harvesting sources
    slim :harvest, :locals => {:library => session[:library]}
  end

  get '/repository' do
    # Misc. repository settings
    #session[:repository] = Repo.new('repository.yml')
    session[:repository] = SETTINGS["repository"]
    slim :repository, :locals => {:library => session[:library], :repo => session[:repository]}
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
