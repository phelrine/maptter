require 'mongo_mapper'

class User
  include MongoMapper::Document
  key :user_id, String
  key :access_token, String
  key :access_secret, String
  many :maps

  attr_protected :access_token, :access_secret
  after_create :create_default_map
  
  def create_default_map
    return unless maps.size == 0
    default_map = Map.new
    default_map.init({:user_id => user_id, :top => 0.5, :left => 0.5})
    maps << default_map
    save
  end
  
  def login(token, secret)
    set(:access_token => token)
    set(:access_secret => secret)
  end

  def current_map
    maps.first
  end
end
