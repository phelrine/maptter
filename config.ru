$:.unshift File.dirname(__FILE__)

require 'sinatra/base'
require 'maptter'

run Maptter
