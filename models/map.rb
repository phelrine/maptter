require 'mongo_mapper'

class Map
  include MongoMapper::EmbeddedDocument
  key :list_name, String
  many :friends

  def init(user)
    friends << Friend.new(user)
    save
  end

  def get_friends
    friends.map{|friend|
      {
        :user_id => friend.user_id,
        :friend_id => friend.id.to_s,
        :top => friend.top,
        :left => friend.left,
      }
    }
  end

  def find_friend(friend_id)
    friends.to_a.find{|f| f.id.to_s == friend_id}
  end

  def add_friend(friend_data)
    friend = Friend.new(friend_data);
    friend.save
    friends << friend
    save
    friend.id
  end
end
