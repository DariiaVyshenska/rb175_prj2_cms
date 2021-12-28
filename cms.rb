require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
# require 'sinatra/content_for'

root = File.expand_path("..", __FILE__)

get '/' do
  @file_names = Dir.glob(root + "/data/*").map do |path|
    File.basename(path)
  end
  erb :index
end
