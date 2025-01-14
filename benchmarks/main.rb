require 'active_support'
require 'active_support/core_ext/hash'
require 'net/http'
require 'brotli'
require 'rails-brotli-cache'
require 'benchmark'
require 'zstd-ruby'

class ZSTDCompressor
  def self.deflate(payload)
    ::Zstd.compress(payload, 10)
  end

  def self.inflate(payload)
    ::Zstd.decompress(payload)
  end
end

memory_cache = ActiveSupport::Cache::MemoryStore.new(compress: true) # memory store does not use compression by default
brotli_memory_cache = RailsBrotliCache::Store.new(memory_cache)
zstd_memory_cache = RailsBrotliCache::Store.new(memory_cache, compressor_class: ZSTDCompressor, prefix: "zs-")

redis_cache = ActiveSupport::Cache::RedisCacheStore.new
brotli_redis_cache = RailsBrotliCache::Store.new(redis_cache)
zstd_redis_cache = RailsBrotliCache::Store.new(redis_cache, compressor_class: ZSTDCompressor, prefix: "zs-")

memcached_cache = ActiveSupport::Cache::MemCacheStore.new
brotli_memcached_cache = RailsBrotliCache::Store.new(memcached_cache)
zstd_memcached_cache = RailsBrotliCache::Store.new(memcached_cache, compressor_class: ZSTDCompressor, prefix: "zs-")

file_cache = ActiveSupport::Cache::FileStore.new('/tmp')
brotli_file_cache = RailsBrotliCache::Store.new(file_cache)
zstd_file_cache = RailsBrotliCache::Store.new(file_cache, compressor_class: ZSTDCompressor, prefix: "zs-")

json_uri = URI("https://raw.githubusercontent.com/pawurb/rails-brotli-cache/main/spec/fixtures/sample.json")
json = Net::HTTP.get(json_uri)

puts "Uncompressed JSON size: #{json.size}"
redis_cache.write("gz-json", json)
gzip_json_size = redis_cache.redis.with do |conn|
  conn.get("gz-json").size
end
puts "Gzip JSON size: #{gzip_json_size}"
brotli_redis_cache.write("json", json)
br_json_size = redis_cache.redis.with do |conn|
  conn.get("br-json").size
end
puts "Brotli JSON size: #{br_json_size}"
puts "~#{((gzip_json_size - br_json_size).to_f / gzip_json_size.to_f * 100).round}% improvment"
puts ""

zstd_redis_cache.write("json", json)
zs_json_size = redis_cache.redis.with do |conn|
  conn.get("zs-json").size
end
puts "ZSTD JSON size: #{zs_json_size}"
puts "~#{((gzip_json_size - zs_json_size).to_f / gzip_json_size.to_f * 100).round}% improvment"
puts ""

iterations = 100

Benchmark.bm do |x|
  x.report("memory_cache") do
    iterations.times do
      memory_cache.write("test", json)
      memory_cache.read("test")
    end
  end

  x.report("brotli_memory_cache") do
    iterations.times do
      brotli_memory_cache.write("test", json)
      brotli_memory_cache.read("test")
    end
  end

  x.report("zstd_memory_cache") do
    iterations.times do
      zstd_memory_cache.write("test", json)
      zstd_memory_cache.read("test")
    end
  end

  x.report("redis_cache") do
    iterations.times do
      redis_cache.write("test", json)
      redis_cache.read("test")
    end
  end

  x.report("brotli_redis_cache") do
    iterations.times do
      brotli_redis_cache.write("test", json)
      brotli_redis_cache.read("test")
    end
  end

  x.report("zstd_redis_cache") do
    iterations.times do
      zstd_redis_cache.write("test", json)
      zstd_redis_cache.read("test")
    end
  end

  x.report("memcached_cache") do
    iterations.times do
      memcached_cache.write("test", json)
      memcached_cache.read("test")
    end
  end

  x.report("brotli_memcached_cache") do
    iterations.times do
      brotli_memcached_cache.write("test", json)
      brotli_memcached_cache.read("test")
    end
  end

  x.report("zstd_memcached_cache") do
    iterations.times do
      zstd_memcached_cache.write("test", json)
      zstd_memcached_cache.read("test")
    end
  end

  x.report("file_cache") do
    iterations.times do
      file_cache.write("test", json)
      file_cache.read("test")
    end
  end

  x.report("brotli_file_cache") do
    iterations.times do
      brotli_file_cache.write("test", json)
      brotli_file_cache.read("test")
    end
  end

  x.report("zstd_file_cache") do
    iterations.times do
      zstd_file_cache.write("test", json)
      zstd_file_cache.read("test")
    end
  end
end
