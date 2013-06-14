#encoding: utf-8
$stdout.sync = true # gives foreman full stdout
require_relative './config/init.rb'
require_relative 'lib/auth'

class APP < Sinatra::Base
  register Sinatra::SessionAuth
  # Global constants
  configure do
  # Sinatra configs
    set :app_file, __FILE__
    set :port, 3000
    set :server, 'thin'
    set :username, SETTINGS["repository"]["username"]
    set :password, SETTINGS["repository"]["password"]
    set :token, 'schabogaijk13@[]5fukkksiur!&&%&%'
    set :session_secret, 'supersecrettokeepsessionsconsistent!'
    enable :logging, :dump_errors, :raise_errors
    enable :reload_templates
    enable :sessions
  end  
  
  configure :development do
    register Sinatra::Reloader
    log = File.new("logs/development.log", "a+") 
  end
  
  configure :production do
    log = File.new("logs/development.log", "a+") 
  end
  
  # use internal session hash for global session, not cookies
  # not used yet
  globalsession = {}

  # Very simple authentication
 # helpers do
 #   def admin? ; request.cookies[settings.username] == settings.token ; end
 #   def protected! ; halt [ 401, 'Not Authorized' ] unless admin? ; end
 # end

  # Routing
  get '/' do
    # Front page
    if authorized?
      slim :index, :locals => {:library => session[:library]}
    else
      slim :about, :locals => {:library => session[:library]}
    end
  end

  get '/libraries' do
    # Library selection
    authorize!
    :json
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
    authorize!
    :json
    session[:library] = Library.find(:id => params[:id].to_i)
    slim :library_menu, :locals => {:library => session[:library]}
  end
      
  get '/mappings' do
    authorize!
    slim :mappings, :locals => {:library => session[:library], :mapping => nil}
  end

  get '/mappings/:id' do
    authorize!
    :json
    # Edit Mapping
    slim :mappings, :locals => {:library => session[:library], :mapping => Mapping.find(:id => params[:id])}
  end

  get '/oai' do
    authorize!
    # oai settings
    :json
    # reload session if updated, can be optimzed!
    session[:library] = session[:library].reload if session[:library] 
    slim :oai, :locals => {:library => session[:library]}
  end
  
  get '/convert' do
    authorize!
    # Main conversion tool
    slim :convert, :locals => {:library => session[:library]}
  end

  # download converted file  
  get '/convert/:filename' do |filename|
    send_file "./db/converted/#{filename}", :filename => filename, :type => 'text/plain'
  end
  
  # show list of files
  get '/files' do
    authorize!
    files = Dir.glob("./db/converted/*.*").map{|f| f.split('/').last}
    # render list here
    slim :files, :locals => {:files => files, :library => session[:library]}
  end

  get '/rules' do
    authorize!
    # Rules creation and management
    slim :rules, :locals => {:library => session[:library], :rule => nil}
  end

  get '/rules/:id' do
    authorize!
    :json
    # Edit rule
    #slim :rules, :escape_html => false, :locals => {:library => session[:library], :rule => Rule.new.find(:id => params[:id])}
    slim :rule_menu, :locals => {:library => session[:library], :rule => Rule.find(:id => params[:id])}
  end
      
  get '/harvesters' do
    authorize!
    # Harvester creation and management
    slim :harvester, :locals => {:library => session[:library], :harvester => nil}
  end

  get '/harvesters/:id' do
    authorize!
    :json
    # Edit harvester
    slim :harvest_menu, :locals => {:library => session[:library], :harvester => Harvest.find(:id => params[:id])}
  end

  get '/status' do
    authorize!
    # status on running/scheduled jobs
    :json
    slim :status, :locals => {:library => session[:library]}
  end
  
  get '/settings' do
    authorize!
    # Misc. settings
    slim :settings, :locals => {:library => session[:library], :settings => SETTINGS}
  end
  
  get '/about' do
    authorize!
    # Front page
    slim :about, :locals => {:library => session[:library]}
  end
=begin
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
=end

  # start the server if ruby file executed directly
  run! if app_file == $0
end
