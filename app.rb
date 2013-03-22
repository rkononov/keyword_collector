require 'sinatra'
require 'faker'
require 'iron_worker_ng'
require 'iron_cache'
require_relative 'helpers/iron_cache_storage.rb'

configure do
  set :public_folder, Proc.new { File.join(root, "static") }
  set :storage, IronCacheStorage.new
end

get '/' do
  @caches = settings.storage.get_caches.select{|c| c=~ /^\d+/}
  @saved = settings.storage.get_from_cache('saved_search')
  erb "Hey"
end

post '/store_question' do
  if params["q"]
    saved = settings.storage.get_from_cache('saved_search')
    puts "Number of questions:#{saved.count}"
    saved << params["q"]
    settings.storage.put_to_cache(saved,'saved_search')
  end
  puts "putting question to cache:#{params.inspect}"
end

post '/remove_question' do
  if params["q"]
    saved = settings.storage.get_from_cache('saved_search')
    puts "Number of questions:#{saved.count}"
    saved.delete(params["q"])
    settings.storage.put_to_cache(saved,'saved_search')
  end
  puts "remove question from cache :#{params.inspect}"
end

get '/cache_results' do
  params["cache"] ? settings.storage.get_from_cache(params["cache"]).to_json : [].to_json
end

get '/cache_details' do
  params["cache"] ? settings.storage.get_value_from_cache('keywords', params["cache"]).to_json : ''
end