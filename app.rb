require 'sinatra/base'
require 'faker'
require 'iron_worker_ng'
require 'iron_cache'
require_relative 'helpers/iron_cache_storage.rb'
my_app = Sinatra.new do
  #set :public_folder, './static' #doesn't work in IronPaas
  set :storage, IronCacheStorage.new
  set :worker, IronWorkerNG::Client.new
  set :port, port = ENV['PORT'] ? ENV['PORT'].to_i : 4567
  enable :logging, :dump_errors, :raise_errors

  #workaround to debug public folder
  get '/static/*' do
    puts "requested file:#{params[:splat]}"
    send_file File.join('static', params[:splat])
  end

  get '/' do
    puts "Hey hey hey!"
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

  post '/queue_worker' do
    puts "PARAMS:#{params.inspect}"
    keywords = params["keywords"] ? params["keywords"].split(',') : ['rabbitmq', 'python+celery', 'message queue', 'python+workers', 'python+background']
    settings.worker.tasks.create("CustomSearchReport", {"keywords"=>keywords})
  end
end
my_app.run!