
require 'rubygems'
require 'sinatra'
require 'faker'
configure do
  set :public_folder, Proc.new { File.join(root, "static") }
end

get '/' do
  erb "Hey"
end

