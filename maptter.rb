# -*- coding: utf-8 -*-
require 'rubygems'
require 'bundler/setup'
require 'sinatra/base'
require 'oauth'
require 'models'

class Maptter < Sinatra::Base
  configure do
    use Rack::Session::Cookie, :secret => User::CONSUMER_SECRET
    MongoMapper.database = "maptter"
    set :logging, true
    set :dump_errors, false
    set :show_exceptions, false
  end
  
  not_found do
    "not found"
  end

  error Rubytter::APIError do
    status 500
    env['sinatra.error'].message
  end

  error do
    status 500
    Model.logger.warn env['sinatra.error'].message
    "sorry..."
  end

  before do
    if request.request_method == "POST"
      halt 500, "not login" unless login?
      halt 500, "invalid token" unless params[:token] == current_user.token
    end
  end
  
  helpers do
    def login? ; session[:user_id] != nil end

    def login! ; redirect '/' unless login? end

    def current_user
      return nil unless login?
      @current_user ||= User.find_by_user_id(session[:user_id])
    end
  end

  get '/' do
    erb :index
  end
  
  get '/oauth' do
    request_token = User.consumer.get_request_token(:oauth_callback => "http://localhost:9393/callback")
    session[:request_token] = request_token.token
    session[:request_secret] = request_token.secret
    redirect request_token.authorize_url
  end

  get '/callback' do
    request_token = OAuth::RequestToken.new(
      User.consumer,
      session[:request_token],
      session[:request_secret]
      )

    access_token = request_token.get_access_token(
      {},
      :oauth_token => params[:oauth_token],
      :oauth_verifier => params[:oauth_verifier]
      )
    user = User.find_or_create_by_user_id(access_token.params[:user_id])
    user.access_token = access_token.token
    user.access_secret = access_token.secret

    if user.maps.size == 0
      map = user.create_map
      user.set_current_map_id(map.id)
    end
    
    session[:user_id] = user.user_id
    session.delete(:request_token)
    session.delete(:request_secret)
    redirect '/'
  end

  get '/logout' do
    session.delete(:user_id)
    redirect '/'
  end

  # Map API
  get '/map/friends' do
    halt 500, "not login" unless login?
    content_type :json
    JSON.unparse current_user.current_map.get_members
  end

  post '/map/save' do
    JSON.parse(params[:tasks]).each{|task|
      task.symbolize_keys!
      next unless task.has_key? :type
      case task[:type]
      when "remove"
        current_user.current_map.remove_member(task[:friend_id])    
      when "move" 
        friend = current_user.current_map.find_member(task[:friend_id])
        friend.move(task[:top], task[:left]) if friend
      end
    }

    content_type :json
    JSON.unparse params
  end

  post '/map/add' do
    params[:friend_id] =current_user.current_map.add_member(params)
    content_type :json 
    JSON.unparse params
  end
  
  # Twitter API
  get '/twitter/timeline' do
    halt 500, "not login" unless login?
    content_type :json
    JSON.unparse current_user.friends_timeline(params)
  end

  post '/twitter/update' do
    content_type :json
    JSON.unparse current_user.tweet(params[:tweet], params)
  end

  post '/twitter/favorite/create' do
    content_type :json
    JSON.unparse current_user.create_favorite(params[:tweet_id])
  end

  post '/twitter/favorite/delete' do
    content_type :json
    JSON.unparse current_user.remove_favorite(params[:tweet_id])
  end
end
