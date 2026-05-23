# frozen_string_literal: true

require_relative "test_helper"

class CacheTest < Minitest::Test
  def test_memory_cache_reads_values_before_expiration
    now = Time.utc(2026, 1, 1)
    cache = Ryfinance::MemoryCache.new(clock: -> { now })

    cache.write("quote", "cached", expires_in: 60)

    assert_equal "cached", cache.read("quote")
    assert_equal 1, cache.size
  end

  def test_memory_cache_expires_values
    now = Time.utc(2026, 1, 1)
    cache = Ryfinance::MemoryCache.new(clock: -> { now })

    cache.write("quote", "cached", expires_in: 60)
    now += 61

    assert_nil cache.read("quote")
    assert_equal 0, cache.size
  end

  def test_memory_cache_evicts_oldest_entry
    cache = Ryfinance::MemoryCache.new(max_size: 1)

    cache.write("first", 1)
    cache.write("second", 2)

    assert_nil cache.read("first")
    assert_equal 2, cache.read("second")
  end
end
