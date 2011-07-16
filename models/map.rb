require 'mongo_mapper'

class Map
  include MongoMapper::EmbeddedDocument
  many :friends
  
  def init(user)
    friends << Friend.new(user)
    save
  end
end
