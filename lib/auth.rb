require 'sinatra/base'

module Sinatra
  module SessionAuth

    module Helpers
      def authorized?
        session[:authorized]
      end

      def authorize!
        redirect '/login' unless authorized?
      end

      def logout!
        session[:authorized] = false
      end
    end

    def self.registered(app)
      app.helpers SessionAuth::Helpers

      app.set :username, 'user'
      app.set :password, 'secret'

      app.get '/login' do
        slim :login
      end

      app.get '/logout' do
        logout!
        session = {}
        redirect '/'
      end
      
      app.post '/login' do
        if params[:user] == settings.username && params[:pass] == settings.password
          session[:authorized] = true
          session[:secret_key] = SETTINGS["secret_session_key"]
          redirect '/'
        else
          #session = {}
          redirect '/login'
        end
      end
    end
  end

  register SessionAuth
end
