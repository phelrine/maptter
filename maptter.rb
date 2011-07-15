require 'rubygems'
require 'bundler/setup'
require 'sinatra/base'

class Maptter < Sinatra::Base
  get '/' do
    erb "Hello Maptter"
  end
end
