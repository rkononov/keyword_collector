require 'sinatra/base'
require 'faker'
require 'iron_worker_ng'
require 'iron_cache'
require_relative 'helpers/iron_cache_storage.rb'

def parse_keywords(p)
  p["keywords"] ? p["keywords"].split(',') : ['rabbitmq', 'python+celery', 'message queue', 'python+workers', 'python+background']
end

my_app = Sinatra.new do
  #set :public_folder, './static' #doesn't work in IronPaas
  set :storage, IronCacheStorage.new
  set :worker, IronWorkerNG::Client.new
  set :port, port = ENV['PORT'] ? ENV['PORT'].to_i : 4567
  enable :logging, :dump_errors, :raise_errors

  #workaround to debug public folder
  get '/static/*' do
    send_file File.join('static', params[:splat])
  end

  get '/' do
    @caches = settings.storage.get_caches.select{|c| c=~ /^\d+/}
    @saved = settings.storage.get_from_cache('saved_search')
    @schedules = settings.worker.schedules.list.select{|s| s.code_name=='CustomSearchReport'}
    puts @schedules.inspect
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
    keywords = parse_keywords(params)
    r = params["run_every"]
    if r && r!="Don't schedule"
      settings.worker.schedules.create("CustomSearchReport", {"keywords"=>keywords},{"run_every" => r.to_i*3600})
    else
      settings.worker.tasks.create("CustomSearchReport", {"keywords"=>keywords})
    end
  end

  post '/cancel_scheduled' do
    id = params[:scheduled_id]
    if id
      settings.worker.schedules.cancel(id)
    end
  end

end
my_app.run!