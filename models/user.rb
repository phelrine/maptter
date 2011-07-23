require 'mongo_mapper'
require 'rubytter'
require 'oauth'

class User
  include MongoMapper::Document
  CONSUMER_KEY, CONSUMER_SECRET = File.open("consumer.cfg").read.split("\n")
  
  key :user_id, String
  key :access_token, String
  key :access_secret, String
  key :current_map_id, ObjectId
  many :maps

  attr_protected :access_token, :access_secret
  
  def self.consumer
    OAuth::Consumer.new(
      CONSUMER_KEY,
      CONSUMER_SECRET,
      :site => "http://api.twitter.com"
      )
  end
  
  def create_map(map_name = "maptter-list")
    list = rubytter(:create_list, user_id, map_name)
    Model.logger.warn "list name changed #{list[:slug]}" unless list[:slug] == map_name
    map = Map.new({:list_id => list[:id_str]})
    maps.push(map)
    save
    map.add_member({:user_id => user_id, :top => 0.5, :left => 0.5})
    Model.logger.info "CREATE_MAP: #{list[:full_name]}(#{list[:id_str]})"
    map
  end
  
  def set_current_map_id(map_id)
    self.current_map_id = map_id
    save
  end
  
  def current_map 
    @current_map ||= Map.find(current_map_id)
  end
  
  def rubytter(api, *args)
    @rubytter ||= OAuthRubytter.new(
      OAuth::AccessToken.new(
        User.consumer,
        access_token,
        access_secret
        )
      )
    begin
      @rubytter.method(api).call(*args)
    rescue Rubytter::APIError => error
      if error.message == "Could not authenticate with OAuth."
        raise OAuthRevoked.new(error.message)
      else
        Model.logger.warn "api error: #{error.message}"
        raise error
      end
    end
  end
  
  class OAuthRevoked < Exception; end
  
  def profile(user_id = self.user_id)
    Cache.get_or_set("profile-#{user_id}", 3600){
      Model.logger.info "PROFILE: #{user_id}"
      rubytter(:user, user_id).to_hash
    }
  end

  def friends_timeline(opt = {})
    Cache.get_or_set("friends-timeline-#{user_id}", 30){
      Model.logger.info "FRIENDS_TIMELINE: #{user_id}"
      rubytter(:friends_timeline, opt).map{|status| status.to_hash}
    }
  end

  def tweet(status, opt = {})
    Model.logger.info "TWEET:#{user_id} #{status}"
    rubytter(:update, status, opt)
  end
end
