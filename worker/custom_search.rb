require 'cgi'
require 'google/api_client'
require 'twitter'
require 'serel'
require 'open-uri'
require 'iron_cache'
require 'yaml'
require 'google-search'

MAX_ITEMS = 100

def initialize_client(api_key)
  Google::APIClient.new(:key => api_key, :authorization => nil)
end

def initialize_stackoverflow(api_key)
  Serel::Base.config(:stackoverflow,api_key)
end

def initialize_iron_cache(config,env)
  client = IronCache::Client.new({"token" => config["iron"]["token"], "project_id" => config["iron"]["project_id"]})
  client.cache(env)
end

def initialize_twitter(twitter_config)
  Twitter.configure do |config|
    config.consumer_key = twitter_config['consumer_key']
    config.consumer_secret = twitter_config['consumer_secret']
    config.oauth_token = twitter_config['oauth_token']
    config.oauth_token_secret = twitter_config['oauth_secret']
  end

end

def get_stackoverflow(k,cache_client)
  res = []
  Serel::Question.pagesize(MAX_ITEMS).filter('!9hnGss2CH').tagged(k.gsub(/\+/,';')).get.each do |q|
    res << {title: q.title, link: q.link, snippet: q.body[0..150]} if new_url?(q.link, cache_client)
  end
  #page = "http://stackoverflow.com/search?tab=newest&pagesize=50&q=title%3A#{CGI.escape(k)}"
  #html = Nokogiri::HTML.parse open(page)
  #html.css('div.result-link a').each do |cite|
  #  link = "http://stackoverflow.com#{cite["href"]}"
  #  res << {title: cite.inner_text, link: link} if new_url?(link, cache_client)
  #end
  res
end

def get_twitter_results(k,cache_client)
  results = []
  Twitter.search(k, rpp: MAX_ITEMS, result_type: "recent", count: MAX_ITEMS).results.each do |r|
    link = "http://twitter.com/#{r.user.screen_name}/status/#{r.id}"
     results << {title: r.text,link: link} if new_url?(link, cache_client)
  end
  results
end

def get_google_results(query,cache_client)
  res = Google::Search::Web.new(:query => query).map{|l| {title:l.content, link: l.uri}}.uniq[0..max_items-1]
  result = []
  res.each do |v|
    result << {title: v.title, link: v.link, snippet: v.html_snippet} if v && new_url?(v.link, cache_client)
  end
  result
end

def new_url?(url, cache_client)
  url = url[0..200] #cutting long urls
  val = cache_client.get(CGI::escape(url))
  puts "Checking #{url}, link #{val ? "found": "not found"}"
  begin
    cache_client.put(CGI::escape(url), {:count => (val ? val.value.to_i : 0) + 1}.to_json)
  rescue =>ex
    puts "Error while putting in cache:#{ex.inspect}"
  end
  val.nil?
end

#-------------------------------WORKER START---------------------------------
env = params['env']||'production'
config = YAML.load_file("config_#{env}.yml")
custom_config = YAML.load_file("config.yml")
puts "CUSTOM_CONFIG:#{custom_config.inspect}"
initialize_stackoverflow(custom_config['stackoverflow']['api_key'])
client = initialize_client(custom_config['google']['api_key'])
initialize_twitter(custom_config['twitter'])
configure_mail(config)
cache_client = initialize_iron_cache(config,env)

#collecting results
results = {}
keywords = params['keywords']||['rabbitmq', 'python+celery', 'message queue', 'python+workers', 'python+background']
keywords.each do |k|
  results[k] ||= {}
  results[k][:quora] = get_google_results(k,cache_client)
  results[k][:twitter] = get_twitter_results(k,cache_client)
  results[k][:stackoverflow] = get_stackoverflow(k,cache_client)
end