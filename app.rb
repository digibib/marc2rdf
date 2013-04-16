#encoding: utf-8
$stdout.sync = true # gives foreman full stdout
require_relative "./config/init.rb"

class APP < Sinatra::Base
  # Global constants
  #Faraday.default_adapter = :em_synchrony  
  configure do
  # Sinatra configs
    #register Sinatra::Synchrony
    #Sinatra::Synchrony.overload_tcpsocket!
    set :app_file, __FILE__
    set :port, 3000
    set :server, 'thin'
    set :username,'bob'
    set :token,'schabogaijk13@[]5fukkksiur!&&%&%'
    set :password,'secret'
    enable :logging, :dump_errors, :raise_errors
    enable :reload_templates
    enable :sessions
  end  
  
  configure :development do
    register Sinatra::Reloader
    log = File.new("logs/development.log", "a+") 
    #STDOUT.reopen(log)
    #STDERR.reopen(log)
    #STDOUT.sync = true
    #STDERR.sync = true
  end
  
  # use internal session hash for global session, not cookies
  # not used yet
  globalsession = {}

  # Very simple authentication
  helpers do
    #Sinatra::Streaming
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
    #session[:library] = session[:library].reload if session[:library] 
    #slim :libraries, :locals => {:library => session[:library]}
    session[:library] = nil
    slim :libraries, :locals => {:library => session[:library]}
  end

  get '/reset' do
    # Reset session and redirect to library selection
    session.clear
    redirect '/libraries'
  end
  
  get '/libraries/:id' do
    # Library settings
    :json
    session[:library] = Library.new.find(:id => params[:id].to_i)
    slim :library_menu, :locals => {:library => session[:library]}
  end
      
  get '/mappings' do
    :json
    slim :mappings, :locals => {:library => session[:library], :mapping => nil}
  end

  get '/mappings/:id' do
    # Edit Mapping
    slim :mappings, :locals => {:library => session[:library], :mapping => Mapping.new.find(:id => params[:id])}
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
  
  get '/convert/:filename' do |filename|
    send_file "./db/converted/#{filename}", :filename => filename, :type => 'text/plain'
  end

  get '/rules' do
    # Rules creation and management
    session[:rule] = nil
    slim :rules, :locals => {:library => session[:library], :rule => session[:rule]}
  end

  get '/rules/:id' do
    :json
    # Edit rule
    session[:rule] = Rule.new.find(:id => params[:id])
    #slim :rules, :escape_html => false, :locals => {:library => session[:library], :rule => Rule.new.find(:id => params[:id])}
    slim :rule_menu, :locals => {:library => session[:library], :rule => session[:rule]}
  end
      
  get '/harvest' do
    # Harvesting sources
    slim :harvest, :locals => {:library => session[:library]}
  end

  get '/status' do
    # status on running/scheduled jobs
    slim :status, :locals => {:library => session[:library]}
  end
  
  get '/repository' do
    # Misc. repository settings
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
