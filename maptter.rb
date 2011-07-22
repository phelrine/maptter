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
    user.login(access_token.token, access_token.secret)
    user.create_default_map
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
    halt 400 unless login?
    content_type :json
    JSON.unparse current_user.current_map.get_members.map{|friend|
      friend.merge(current_user.profile(friend[:user_id]))
    }
  end

  post '/map/move' do
    halt 400 unless login?
    JSON.parse(params[:tasks]).each{|task|
      task.symbolize_keys!
      friend = current_user.current_map.find_member(task[:friend_id])
      if friend
        friend.move(task[:top], task[:left])
        params[:result] = true
      else
        params[:result] = false
      end
    }

    content_type :json
    JSON.unparse params
  end

  post '/map/add' do
    halt 400 unless login?
    
    params[:friend_id] =current_user.current_map.add_member(params)
    content_type :json 
    JSON.unparse params
  end
  
  # Twitter API
  get '/twitter/timeline' do
    halt 400 unless login?
    opt = {}
    %w[since count].each{|e| 
      opt[e] = params[e] if params.has_key? e 
    }
    content_type :json
    JSON.unparse current_user.friends_timeline(opt)
  end

  post '/twitter/update' do
    halt 400 unless login?
    opt = {}
    %w[in_reply_to_status_id].each{|key|
      opt[key] = params[key] if params.has_key? key
    }
    JSON.unparse current_user.tweet(params[:tweet], opt)
  end
end
