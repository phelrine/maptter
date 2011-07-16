require 'mongo_mapper'

class Friend
  include MongoMapper::EmbeddedDocument
  key :user_id, String
  key :top, Float
  key :left, Float
end

