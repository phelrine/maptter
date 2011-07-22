require 'mongo_mapper'

class Map
  include MongoMapper::Document
  belongs_to :user
  key :list_name, String
  many :friends

  def get_members
    friends.map{|friend|
      {
        :user_id => friend.user_id,
        :friend_id => friend.id.to_s,
        :top => friend.top,
        :left => friend.left,
      }
    }
  end

  def find_member(friend_id)
    friends.to_a.find{|f| f.id.to_s == friend_id}
  end

  def add_member(friend_data)
    friend_data.symbolize_keys
    friend = Friend.new(friend_data);
    friend.save
    friends << friend
    save
    user = User.find(user_id)
    user.rubytter(:add_member_to_list, user.user_id, list_name, friend_data[:user_id])
    friend.id
  end
end
