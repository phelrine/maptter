require 'mongo_mapper'

class User
  include MongoMapper::Document
  key :user_id, String
  key :access_token, String
  key :access_secret, String
  
  attr_protected :access_token, :access_secret
  
  def login(token, secret)
    set(:access_token => token)
    set(:access_secret => secret)
  end
  
end
