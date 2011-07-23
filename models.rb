require 'models/user'
require 'models/map'
require 'models/friend'
require 'models/cache'
require 'logger'

module Model
  def self.logger
    @logger ||= Logger.new($stderr)
  end
end
