# frozen_string_literal: true

module Ryfinance
  class MemoryCache
    Entry = Struct.new(:value, :expires_at, keyword_init: true)

    def initialize(max_size: nil, clock: -> { Time.now })
      @max_size = max_size
      @clock = clock
      @entries = {}
      @mutex = Mutex.new
    end

    def read(key)
      @mutex.synchronize do
        entry = @entries[key]
        return nil unless entry

        if expired?(entry)
          @entries.delete(key)
          return nil
        end

        entry.value
      end
    end

    def write(key, value, expires_in: nil)
      @mutex.synchronize do
        prune_expired
        evict_oldest if @max_size && @entries.size >= @max_size && !@entries.key?(key)
        @entries[key] = Entry.new(value: value, expires_at: expires_at(expires_in))
      end

      value
    end

    def delete(key)
      @mutex.synchronize { @entries.delete(key) }
    end

    def clear
      @mutex.synchronize { @entries.clear }
      self
    end

    def size
      @mutex.synchronize do
        prune_expired
        @entries.size
      end
    end

    private

    def expires_at(expires_in)
      return nil if expires_in.nil?

      @clock.call + expires_in.to_f
    end

    def expired?(entry)
      entry.expires_at && entry.expires_at <= @clock.call
    end

    def prune_expired
      @entries.delete_if { |_key, entry| expired?(entry) }
    end

    def evict_oldest
      oldest_key = @entries.keys.first
      @entries.delete(oldest_key) if oldest_key
    end
  end
end
