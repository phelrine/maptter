require 'mongo_mapper'

class Map
  include MongoMapper::Document
  belongs_to :user
  key :list_id, String
  many :friends

  def owner
    @owner ||= User.find(user_id)
  end

  def list_api(api, opt)
    begin
      owner.rubytter(api, owner.user_id, list_id, opt)
    rescue Rubytter::APIError => error
      if error.message == "Not found"
        list = owner.create_list
        self.list_id = list[:id_str]
        save
        owner.rubytter(api, owner.user_id, list_id, opt)
      else
        raise error
      end
    end
  end

  def member_profiles
    @member_profiles ||= Cache.get_or_set("list-#{id}", 3600){
      profiles = {}
      has_next = -1
      while has_next != 0
        Model.logger.info "LIST_NEXT_CURSOR: #{id} #{has_next}"
        list_members = list_api(:list_members, {:cursor => has_next})
        has_next = list_members[:next_cursor]
        list_members[:users].to_a.each{|profile|
          profiles[profile.id_str] = profile.to_hash
        }
      end
      Model.logger.info "LIST_MEMBER: #{id}"
      profiles
    }
  end
  
  def get_members
    reset_cache = false
    members = friends.map{|friend|
      member_profiles.fetch(friend.user_id){
        Model.logger.warn "profile not found: #{friend.user_id}"
        reset_cache = true
        list_api(:add_member_to_list, friend.user_id)
        profile = owner.profile(friend.user_id)
      }.merge({
          :user_id => friend.user_id,
          :friend_id => friend.id.to_s,
          :top => friend.top,
          :left => friend.left,
        })
    }
    Cache.delete("list-#{id}") if reset_cache 
    members
  end

  def find_member(friend_id)
    friends.to_a.find{|f| f.id.to_s == friend_id}
  end

  def add_member(friend_data)
    friend_data.symbolize_keys!
    if friend_data.has_key? :profile
      profile = friend_data[:profile].symbolize_keys
      Cache.set("list-#{id}", member_profiles.merge({profile[:id_str] => profile}), 3600)
      friend_data.delete(:profile)
    end
    list_api(:add_member_to_list, friend_data[:user_id])
    Model.logger.info "ADD_MEMBER: #{list_id} #{friend_data[:user_id]}"
    friend = Friend.new(%w[user_id top left].map(&:to_sym).inject({}){|data, key|
        raise "friend must have #{key}" unless friend_data.has_key? key
        data[key] = friend_data[key]
        data
      });
    friends.push(friend)
    save
    friend.id
  end

  def remove_member(friend_id)
    index = friends.index{|f| f.id.to_s == friend_id }
    unless index
      Model.logger.warn "user not found #{friend_id}"
      return {:result => false} 
    end
    friend = friends[index]
    friends.delete_at(index)
    save
    list_api(:remove_member_from_list, friend.user_id)
    Model.logger.info "REMOVE_MEMBER: #{list_id} #{friend.user_id}"
  end

end
