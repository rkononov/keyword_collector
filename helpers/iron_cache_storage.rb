class IronCacheStorage

  def initialize
    @client = IronCache::Client.new
  end

  def get_from_cache(cache_name)
    cache = @client.cache(cache_name)
    values = []
    100.times do |i|
      values_from_cache = cache.get("values_#{i}")
      return values unless values_from_cache
      values += JSON.parse(values_from_cache.value)
    end
  end

  def put_to_cache(values, cache_name)
    cache = @client.cache(cache_name)
    #we need chunked list because we need to break results in pieces less then 64kb
    values.each_slice(100).to_a.each_with_index do |list, index|
      cache.put("values_#{index}", list.to_json)
    end
    #cleaning out last item if exist, we need this if new list smaller then previous
    puts cache.delete("values_#{values.count+1}") rescue "not exist"
  end

  def put_value_to_cache(value,key_name, cache_name)
    cache = @client.cache(cache_name)
    cache.put(key_name, value.to_json)
  end

  def get_value_from_cache(key_name, cache_name)
    cache = @client.cache(cache_name)
    JSON.parse cache.get(key_name).value
  end

  def get_caches
    @client.caches.list.map(&:name)
  end

end