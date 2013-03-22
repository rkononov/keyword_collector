require 'json'
require 'cgi'
require 'google/api_client'
require 'twitter'
require 'serel'
require 'open-uri'
require 'iron_cache'
require 'yaml'
require 'google-search'
require 'iron_cache_storage'

MAX_ITEMS = 10

def initialize_stackoverflow(api_key)
  Serel::Base.config(:stackoverflow,api_key)
end

def initialize_iron_cache(env)
  client = IronCache::Client.new
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
    res << {title: q.title, link: q.link, snippet: q.body[0..150],source:'stackoverflow'} if new_url?(q.link, cache_client)
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
     results << {title: r.text,link: link, source:'twitter'} if new_url?(link, cache_client)
  end
  results
end

def get_google_results(query,cache_client)
  res = Google::Search::Web.new(:query => "#{query} site:quora.com").map{|l| {title:l.content, link: l.uri}}.uniq
  result = []
  res.each do |v|
    result << v.merge({source:'quora'}) if v && new_url?(v[:link], cache_client)
    break if result.size >= MAX_ITEMS
  end
  result
end

def new_url?(url, cache_client)
  return true
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
custom_config = YAML.load_file("config.yml")
puts "CUSTOM_CONFIG:#{custom_config.inspect}"
initialize_stackoverflow(custom_config['stackoverflow']['api_key'])
initialize_twitter(custom_config['twitter'])
cache_client = initialize_iron_cache(env)

#collecting results
keywords = params['keywords']||['rabbitmq', 'python+celery', 'message queue', 'python+workers', 'python+background']
results = []
keywords.each do |k|
  results += get_google_results(k,cache_client)
  #results += get_twitter_results(k,cache_client)
  results += get_stackoverflow(k,cache_client)
end
#putting all of them into cache
cache_name = (Time.now.strftime("%Y-%m-%d_%H:%M_") + keywords.join('_')).gsub(/ /,'-')
cache_name = cache_name.length > 40 ? "#{cache_name[0..40]}..." : cache_name
storage = IronCacheStorage.new
puts "Putting to cache:#{results.inspect}"
storage.put_to_cache(results, cache_name)
storage.put_value_to_cache(keywords,'keywords', cache_name)