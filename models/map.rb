require 'mongo_mapper'

class Map
  include MongoMapper::Document
  belongs_to :user
  key :list_id, String
  many :friends

  def owner
    @owner ||= User.find(user_id)
  end
  
  def member_profiles
    @member_profiles ||= Cache.get_or_set("list-#{id}", 3600){
      profiles = {}
      has_next = -1
      while has_next != 0
        list_members = owner.rubytter(:list_members, owner.user_id, list_id, {
            :cursor => has_next
          })
        has_next = list_members[:next_cursor]
        list_members[:users].to_a.each{|profile|
          profiles[profile.id_str] = profile.to_hash
        }
      end
      profiles
    }
  end
  
  def get_members
    friends.map{|friend|
      profile = member_profiles[friend.user_id]
      unless profile 
        owner.rubytter(:add_member_to_list, owner.user_id, list_id, friend.user_id)
        profile = owner.profile(friend.user_id)
      end
      profile.merge({
          :user_id => friend.user_id,
          :friend_id => friend.id.to_s,
          :top => friend.top,
          :left => friend.left,
        })
    }
  end

  def find_member(friend_id)
    friends.to_a.find{|f| f.id.to_s == friend_id}
  end

  def add_member(friend_data)
    friend_data.symbolize_keys
    owner.rubytter(:add_member_to_list, owner.user_id, list_id, friend_data[:user_id])
    friend = Friend.new(friend_data);
    friends.push(friend)
    friend.save
    save
    friend.id
  end

  def remove_member(friend_id)
    index = friends.index{|f| f.id.to_s == friend_id }
    return {:result => false } unless index
    
    friend = friends[index]
    owner.rubytter(:remove_member_from_list, owner.user_id, list_id, friend.user_id)
    result = {:result => true, :user_id => friend.user_id}
    friends.delete_at(index)
    save
    result
  end
end
