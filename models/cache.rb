require "dalli"

module Cache
  def self.instance
    Dalli::Client.new('127.0.0.1:11211')
  end

  def self.get_or_set(key, expire)
    raise "block needed" unless block_given?
    key = key.to_s
    cache = self.instance.get(key)
    return cache if cache

    new_value = yield
    self.instance.set(key, new_value, expire)
    new_value
  rescue => error
    new_value || yield
  end

  def self.delete(key)
    self.instance.delete(key)
  end
end
