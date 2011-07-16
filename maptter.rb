# -*- coding: utf-8 -*-
require 'rubygems'
require 'bundler/setup'
require 'sinatra/base'
require 'oauth'
require 'models'

class Maptter < Sinatra::Base
  configure do
    use Rack::Session::Cookie, :secret => "change"
    CONSUMER_KEY, CONSUMER_SECRET = File.open("consumer.cfg").read.split("\n")
    MongoMapper.database = "maptter"
  end
  
  helpers do
    def consumer
      OAuth::Consumer.new(
        CONSUMER_KEY,
        CONSUMER_SECRET,
        :site => "http://api.twitter.com"
        )
    end
    
    def login? ; session[:user_id] != nil end
    
    def login! ; redirect '/' unless login? end

    def current_usr
      return nil unless login?
      @current_usr ||= User.find_by_user_id(session[:user_id])
    end
  end

  get '/' do
    erb "Hello Maptter <a href='/oauth'>login</a>"
  end
  
  get '/oauth' do
    request_token = consumer.get_request_token(:oauth_callback => "http://localhost:9393/callback")
    session[:request_token] = request_token.token
    session[:request_secret] = request_token.secret
    redirect request_token.authorize_url
  end

  get '/callback' do
    request_token = OAuth::RequestToken.new(
      consumer,
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
    session[:user_id] = user.user_id
    session.delete(:request_token)
    session.delete(:request_secret)
    redirect '/'
  end

  get '/logout' do
    session.delete(:user_id)
  end

  # Map API
  get '/map/timeline' do 
    # 対象マップのタイムラインを取得
    # params : map_id 
  end
  
  get '/map/friends' do
    # 対象マップのfriends一覧を取得
    # params : map_id 
  end

  post '/map/move' do
    # 対象マップのユーザーの位置を変更
    # params : map_id user_id top left
  end

  # Twitter API ...
end
